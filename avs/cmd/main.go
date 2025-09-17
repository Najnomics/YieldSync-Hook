package main

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"time"

	"github.com/Layr-Labs/hourglass-monorepo/ponos/pkg/performer/server"
	performerV1 "github.com/Layr-Labs/protocol-apis/gen/protos/eigenlayer/hourglass/v1/performer"
	"go.uber.org/zap"
)

// TaskType represents the different types of YieldSync tasks
type TaskType string

const (
	TaskTypeYieldMonitoring    TaskType = "yield_monitoring"
	TaskTypePositionAdjustment TaskType = "position_adjustment"
	TaskTypeRiskAssessment     TaskType = "risk_assessment"
	TaskTypeRebalancing        TaskType = "rebalancing"
	TaskTypeLSTValidation      TaskType = "lst_validation"
)

// LSTData represents LST yield data
type LSTData struct {
	TokenAddress    string    `json:"token_address"`
	CurrentYield    *big.Int  `json:"current_yield"`
	HistoricalYield []*big.Int `json:"historical_yield"`
	RiskScore       uint8     `json:"risk_score"`
	LastUpdate      time.Time `json:"last_update"`
	Validator       string    `json:"validator"`
}

// PositionData represents LP position information
type PositionData struct {
	PoolId          string   `json:"pool_id"`
	LowerTick       int24    `json:"lower_tick"`
	UpperTick       int24    `json:"upper_tick"`
	Liquidity       *big.Int `json:"liquidity"`
	Token0Amount    *big.Int `json:"token0_amount"`
	Token1Amount    *big.Int `json:"token1_amount"`
	LastAdjustment  time.Time `json:"last_adjustment"`
}

// TaskPayload represents the structure of YieldSync task payload data
type TaskPayload struct {
	Type       TaskType               `json:"type"`
	Parameters map[string]interface{} `json:"parameters"`
	LSTData    []LSTData             `json:"lst_data,omitempty"`
	Position   *PositionData         `json:"position,omitempty"`
}

// YieldAdjustmentResult represents the result of yield-based position adjustment
type YieldAdjustmentResult struct {
	AdjustmentRequired bool      `json:"adjustment_required"`
	NewLowerTick       int24     `json:"new_lower_tick,omitempty"`
	NewUpperTick       int24     `json:"new_upper_tick,omitempty"`
	ReasonCode         string    `json:"reason_code"`
	YieldDifference    *big.Int  `json:"yield_difference,omitempty"`
	RiskAssessment     uint8     `json:"risk_assessment"`
	Timestamp          time.Time `json:"timestamp"`
}

// parseTaskPayload extracts and parses the task payload from TaskRequest
func parseTaskPayload(t *performerV1.TaskRequest) (*TaskPayload, error) {
	var payload TaskPayload
	if err := json.Unmarshal(t.Payload, &payload); err != nil {
		return nil, fmt.Errorf("failed to parse YieldSync task payload: %w", err)
	}
	return &payload, nil
}

// YieldSyncPerformer implements the Hourglass Performer interface for YieldSync tasks.
// This offchain binary is run by Operators running the Hourglass Executor. It contains
// the business logic of the YieldSync AVS and performs LST yield monitoring and 
// position adjustment calculations based on tasks sent to it.
//
// The Hourglass Aggregator ingests tasks from the TaskMailbox and distributes work
// to Executors configured to run the YieldSync Performer. Performers execute the work and
// return the result to the Executor where the result is signed and returned to the
// Aggregator to place in the outbox once the signing threshold is met.
type YieldSyncPerformer struct {
	logger     *zap.Logger
	startTime  time.Time
	taskCount  uint64
}

func NewYieldSyncPerformer(logger *zap.Logger) *YieldSyncPerformer {
	return &YieldSyncPerformer{
		logger:    logger,
		startTime: time.Now(),
		taskCount: 0,
	}
}

func (ysp *YieldSyncPerformer) ValidateTask(t *performerV1.TaskRequest) error {
	ysp.logger.Sugar().Infow("Validating YieldSync task",
		zap.Any("task", t),
	)

	// ------------------------------------------------------------------------
	// YieldSync Task Validation Logic
	// ------------------------------------------------------------------------
	// Validate that the task request data is well-formed for YieldSync operations
	
	if len(t.TaskId) == 0 {
		return fmt.Errorf("task ID cannot be empty")
	}

	if len(t.Payload) == 0 {
		return fmt.Errorf("task payload cannot be empty")
	}

	// Parse and validate payload structure
	payload, err := parseTaskPayload(t)
	if err != nil {
		return fmt.Errorf("invalid task payload structure: %w", err)
	}

	// Validate task type
	switch payload.Type {
	case TaskTypeYieldMonitoring, TaskTypePositionAdjustment, TaskTypeRiskAssessment, 
		 TaskTypeRebalancing, TaskTypeLSTValidation:
		// Valid task types
	default:
		return fmt.Errorf("invalid task type: %s", payload.Type)
	}

	// Task-specific validation
	switch payload.Type {
	case TaskTypeYieldMonitoring:
		if err := ysp.validateYieldMonitoringTask(payload); err != nil {
			return fmt.Errorf("yield monitoring task validation failed: %w", err)
		}
	case TaskTypePositionAdjustment:
		if err := ysp.validatePositionAdjustmentTask(payload); err != nil {
			return fmt.Errorf("position adjustment task validation failed: %w", err)
		}
	case TaskTypeRiskAssessment:
		if err := ysp.validateRiskAssessmentTask(payload); err != nil {
			return fmt.Errorf("risk assessment task validation failed: %w", err)
		}
	case TaskTypeRebalancing:
		if err := ysp.validateRebalancingTask(payload); err != nil {
			return fmt.Errorf("rebalancing task validation failed: %w", err)
		}
	case TaskTypeLSTValidation:
		if err := ysp.validateLSTValidationTask(payload); err != nil {
			return fmt.Errorf("LST validation task validation failed: %w", err)
		}
	}

	ysp.logger.Sugar().Infow("YieldSync task validation successful", "taskId", string(t.TaskId), "type", payload.Type)
	return nil
}

func (ysp *YieldSyncPerformer) HandleTask(t *performerV1.TaskRequest) (*performerV1.TaskResponse, error) {
	ysp.logger.Sugar().Infow("Handling YieldSync task",
		zap.Any("task", t),
	)

	ysp.taskCount++

	// ------------------------------------------------------------------------
	// YieldSync Task Processing Logic
	// ------------------------------------------------------------------------
	// This is where the Performer will execute YieldSync-specific work
	
	var resultBytes []byte
	var err error

	// Parse task payload to determine task type
	payload, err := parseTaskPayload(t)
	if err != nil {
		return nil, fmt.Errorf("failed to parse task payload: %w", err)
	}
	
	// Route to appropriate handler based on task type
	switch payload.Type {
	case TaskTypeYieldMonitoring:
		resultBytes, err = ysp.handleYieldMonitoring(t, payload)
	case TaskTypePositionAdjustment:
		resultBytes, err = ysp.handlePositionAdjustment(t, payload)
	case TaskTypeRiskAssessment:
		resultBytes, err = ysp.handleRiskAssessment(t, payload)
	case TaskTypeRebalancing:
		resultBytes, err = ysp.handleRebalancing(t, payload)
	case TaskTypeLSTValidation:
		resultBytes, err = ysp.handleLSTValidation(t, payload)
	default:
		return nil, fmt.Errorf("unknown task type '%s' for task %s", payload.Type, string(t.TaskId))
	}

	if err != nil {
		ysp.logger.Sugar().Errorw("YieldSync task processing failed", 
			"taskId", string(t.TaskId), 
			"type", payload.Type,
			"error", err,
		)
		return nil, err
	}

	ysp.logger.Sugar().Infow("YieldSync task processing completed successfully", 
		"taskId", string(t.TaskId),
		"type", payload.Type,
		"resultSize", len(resultBytes),
		"totalTasksProcessed", ysp.taskCount,
	)

	return &performerV1.TaskResponse{
		TaskId: t.TaskId,
		Result: resultBytes,
	}, nil
}

// handleYieldMonitoring processes LST yield monitoring tasks
func (ysp *YieldSyncPerformer) handleYieldMonitoring(t *performerV1.TaskRequest, payload *TaskPayload) ([]byte, error) {
	ysp.logger.Sugar().Infow("Processing yield monitoring task", "taskId", string(t.TaskId))
	
	// Extract parameters
	poolAddress, ok := payload.Parameters["pool_address"].(string)
	if !ok {
		return nil, fmt.Errorf("missing or invalid pool_address parameter")
	}

	threshold, ok := payload.Parameters["threshold"].(float64)
	if !ok {
		threshold = 0.01 // Default 1% threshold
	}

	// Simulate yield monitoring logic
	// In a real implementation, this would:
	// - Query current LST yields from various sources
	// - Compare against historical data
	// - Detect significant yield changes
	// - Return monitoring results
	
	result := map[string]interface{}{
		"pool_address": poolAddress,
		"yield_change_detected": true,
		"threshold_exceeded": threshold > 0.005,
		"current_yields": payload.LSTData,
		"timestamp": time.Now(),
		"monitoring_status": "active",
	}

	return json.Marshal(result)
}

// handlePositionAdjustment processes position adjustment calculation tasks
func (ysp *YieldSyncPerformer) handlePositionAdjustment(t *performerV1.TaskRequest, payload *TaskPayload) ([]byte, error) {
	ysp.logger.Sugar().Infow("Processing position adjustment task", "taskId", string(t.TaskId))
	
	if payload.Position == nil {
		return nil, fmt.Errorf("position data required for adjustment task")
	}

	// Extract adjustment parameters
	targetYield, ok := payload.Parameters["target_yield"].(float64)
	if !ok {
		targetYield = 0.05 // Default 5% target yield
	}

	maxSlippage, ok := payload.Parameters["max_slippage"].(float64)
	if !ok {
		maxSlippage = 0.005 // Default 0.5% max slippage
	}

	// Simulate position adjustment calculation
	// In a real implementation, this would:
	// - Analyze current position performance
	// - Calculate optimal tick ranges based on yield data
	// - Consider gas costs and slippage
	// - Return adjustment recommendations

	adjustmentResult := YieldAdjustmentResult{
		AdjustmentRequired: true,
		NewLowerTick:      payload.Position.LowerTick - 100, // Example adjustment
		NewUpperTick:      payload.Position.UpperTick + 100,
		ReasonCode:        "yield_optimization",
		YieldDifference:   big.NewInt(150), // 1.5% improvement
		RiskAssessment:    3, // Medium risk
		Timestamp:         time.Now(),
	}

	return json.Marshal(adjustmentResult)
}

// handleRiskAssessment processes risk assessment tasks
func (ysp *YieldSyncPerformer) handleRiskAssessment(t *performerV1.TaskRequest, payload *TaskPayload) ([]byte, error) {
	ysp.logger.Sugar().Infow("Processing risk assessment task", "taskId", string(t.TaskId))
	
	// Simulate risk assessment logic
	// In a real implementation, this would:
	// - Analyze LST validator performance
	// - Check slashing history
	// - Evaluate market conditions
	// - Calculate composite risk scores

	riskAssessment := map[string]interface{}{
		"overall_risk_score": 4, // Out of 10
		"validator_risk": 3,
		"market_risk": 5,
		"liquidity_risk": 2,
		"recommendation": "moderate_exposure",
		"timestamp": time.Now(),
	}

	return json.Marshal(riskAssessment)
}

// handleRebalancing processes portfolio rebalancing tasks
func (ysp *YieldSyncPerformer) handleRebalancing(t *performerV1.TaskRequest, payload *TaskPayload) ([]byte, error) {
	ysp.logger.Sugar().Infow("Processing rebalancing task", "taskId", string(t.TaskId))
	
	// Extract rebalancing parameters
	rebalanceThreshold, ok := payload.Parameters["rebalance_threshold"].(float64)
	if !ok {
		rebalanceThreshold = 0.02 // Default 2% threshold
	}

	// Simulate rebalancing logic
	// In a real implementation, this would:
	// - Calculate current portfolio allocation
	// - Compare against target allocation
	// - Generate rebalancing instructions
	// - Optimize for gas efficiency

	rebalanceResult := map[string]interface{}{
		"rebalance_required": true,
		"target_allocation": map[string]float64{
			"stETH": 0.4,
			"rETH":  0.35,
			"cbETH": 0.25,
		},
		"current_deviation": 0.025, // 2.5% deviation
		"gas_estimate": "0.015", // ETH
		"timestamp": time.Now(),
	}

	return json.Marshal(rebalanceResult)
}

// handleLSTValidation processes LST validation tasks
func (ysp *YieldSyncPerformer) handleLSTValidation(t *performerV1.TaskRequest, payload *TaskPayload) ([]byte, error) {
	ysp.logger.Sugar().Infow("Processing LST validation task", "taskId", string(t.TaskId))
	
	// Extract validation parameters
	tokenAddress, ok := payload.Parameters["token_address"].(string)
	if !ok {
		return nil, fmt.Errorf("missing token_address parameter")
	}

	// Simulate LST validation logic
	// In a real implementation, this would:
	// - Verify LST contract authenticity
	// - Check validator set health
	// - Validate yield calculation methods
	// - Return validation status

	validationResult := map[string]interface{}{
		"token_address": tokenAddress,
		"is_valid": true,
		"validator_count": 1250,
		"health_score": 95,
		"yield_method_verified": true,
		"last_slashing_event": nil,
		"timestamp": time.Now(),
	}

	return json.Marshal(validationResult)
}

// Validation helper functions

func (ysp *YieldSyncPerformer) validateYieldMonitoringTask(payload *TaskPayload) error {
	if _, ok := payload.Parameters["pool_address"]; !ok {
		return fmt.Errorf("pool_address parameter required")
	}
	return nil
}

func (ysp *YieldSyncPerformer) validatePositionAdjustmentTask(payload *TaskPayload) error {
	if payload.Position == nil {
		return fmt.Errorf("position data required")
	}
	return nil
}

func (ysp *YieldSyncPerformer) validateRiskAssessmentTask(payload *TaskPayload) error {
	if len(payload.LSTData) == 0 {
		return fmt.Errorf("LST data required for risk assessment")
	}
	return nil
}

func (ysp *YieldSyncPerformer) validateRebalancingTask(payload *TaskPayload) error {
	if payload.Position == nil {
		return fmt.Errorf("position data required for rebalancing")
	}
	return nil
}

func (ysp *YieldSyncPerformer) validateLSTValidationTask(payload *TaskPayload) error {
	if _, ok := payload.Parameters["token_address"]; !ok {
		return fmt.Errorf("token_address parameter required")
	}
	return nil
}

func main() {
	ctx := context.Background()
	l, _ := zap.NewProduction()

	performer := NewYieldSyncPerformer(l)

	pp, err := server.NewPonosPerformerWithRpcServer(&server.PonosPerformerConfig{
		Port:    8080,
		Timeout: 10 * time.Second, // Longer timeout for complex calculations
	}, performer, l)
	if err != nil {
		panic(fmt.Errorf("failed to create YieldSync performer: %w", err))
	}

	l.Info("Starting YieldSync Performer on port 8080...")
	l.Info("YieldSync AVS ready to process LST yield monitoring and position adjustment tasks")
	
	if err := pp.Start(ctx); err != nil {
		panic(err)
	}
}