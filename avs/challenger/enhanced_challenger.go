package challenger

import (
	"context"
	"fmt"
	"math"
	"math/big"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/prometheus/client_golang/prometheus"

	"github.com/Layr-Labs/eigensdk-go/chainio/clients"
	"github.com/Layr-Labs/eigensdk-go/chainio/clients/eth"
	sdkcontracts "github.com/Layr-Labs/eigensdk-go/chainio/clients/elcontracts"
	sdklogging "github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/Layr-Labs/eigensdk-go/services/avsregistry"
	"github.com/Layr-Labs/eigensdk-go/services/operatorsinfo"
	sdktypes "github.com/Layr-Labs/eigensdk-go/types"

	"github.com/YieldSync/yieldsync-hook/avs/challenger/types"
	"github.com/YieldSync/yieldsync-hook/avs/core"
	"github.com/YieldSync/yieldsync-hook/avs/metrics"
)

const (
	AVS_NAME = "yieldsync"
	SEM_VER  = "0.1.0"

	// Challenge parameters
	CHALLENGE_WINDOW_BLOCKS    = 100
	YIELD_TOLERANCE_BPS        = 10  // 0.1% tolerance for yield rate verification
	MAX_YIELD_RATE_BPS         = 10000 // 100% maximum reasonable yield rate
	CHALLENGE_REWARD_ETH       = 0.01  // Reward for successful challenge
)

// EnhancedChallenger verifies task responses and submits challenges for incorrect responses
type EnhancedChallenger struct {
	config    core.NodeConfig
	logger    sdklogging.Logger
	ethClient eth.Client

	// EigenLayer services
	elClients             *clients.Clients
	elContracts           *sdkcontracts.Clients
	avsReader            core.AvsReaderer
	avsWriter            core.AvsWriter
	avsSubscriber        core.AvsSubscriberer
	operatorsInfoService  operatorsinfo.OperatorsInfoService
	avsRegistryService   avsregistry.AvsRegistryService

	// LST monitors for verification
	lstMonitors map[string]*core.LSTMonitor

	// Challenge tracking
	challengeMutex         sync.RWMutex
	activeChallenges       map[uint32]*types.ChallengeInfo
	challengeHistory       map[uint32]*types.ChallengeResult
	challengeWindow        time.Duration

	// Verified response cache to avoid re-checking
	verifiedResponses      map[uint32]bool
	verifiedResponsesMutex sync.RWMutex

	// Metrics and monitoring
	metricsRegistry *prometheus.Registry
	metrics         *metrics.ChallengerMetrics

	// Context and cancellation
	ctx    context.Context
	cancel context.CancelFunc
}

// NewEnhancedChallenger creates a new enhanced challenger
func NewEnhancedChallenger(config core.NodeConfig) (*EnhancedChallenger, error) {
	ctx, cancel := context.WithCancel(context.Background())

	// Setup logger
	logger, err := sdklogging.NewZapLogger(config.Logger.Level)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create logger: %w", err)
	}

	// Setup Ethereum client
	ethClient, err := eth.NewClient(config.EthRpcUrl, config.EthWsUrl)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create eth client: %w", err)
	}

	// Setup EigenLayer clients
	elClients, err := clients.NewClients(
		config.EthRpcUrl,
		config.EthWsUrl,
		common.HexToAddress(config.Challenger.ChallengerAddress),
		ethClient,
	)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create eigenlayer clients: %w", err)
	}

	// Setup EigenLayer contracts
	elContracts, err := sdkcontracts.NewClients(
		common.HexToAddress(config.EigenLayer.ServiceManagerAddr),
		common.HexToAddress(config.EigenLayer.DelegationManagerAddr),
		common.HexToAddress(config.EigenLayer.StrategyManagerAddr),
		common.HexToAddress(config.EigenLayer.AVSDirectoryAddress),
		elClients,
	)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create eigenlayer contracts: %w", err)
	}

	// Setup AVS services
	avsReader, err := core.NewAvsReader(
		common.HexToAddress(config.EigenLayer.ServiceManagerAddr),
		common.HexToAddress(config.EigenLayer.TaskManagerAddr),
		ethClient,
		logger,
	)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create avs reader: %w", err)
	}

	avsWriter, err := core.NewAvsWriter(
		common.HexToAddress(config.EigenLayer.ServiceManagerAddr),
		common.HexToAddress(config.EigenLayer.TaskManagerAddr),
		common.HexToAddress(config.Challenger.ChallengerAddress),
		ethClient,
		logger,
	)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create avs writer: %w", err)
	}

	avsSubscriber, err := core.NewAvsSubscriber(
		common.HexToAddress(config.EigenLayer.ServiceManagerAddr),
		common.HexToAddress(config.EigenLayer.TaskManagerAddr),
		ethClient,
		logger,
	)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create avs subscriber: %w", err)
	}

	// Setup operators info service
	operatorsInfoService := operatorsinfo.NewOperatorsInfoServiceInMemory(
		context.Background(),
		elClients.AvsRegistryCoordinator,
		elClients.OperatorStateRetriever,
		logger,
	)

	// Setup AVS registry service
	avsRegistryService := avsregistry.NewAvsRegistryService(
		avsReader,
		logger,
	)

	// Setup LST monitors for yield verification
	lstMonitors := make(map[string]*core.LSTMonitor)
	if config.LSTMonitoring.LidoStETHAddress != "" {
		lstMonitors["stETH"] = core.NewLSTMonitor("stETH", config.LSTMonitoring.LidoStETHAddress, logger)
	}
	if config.LSTMonitoring.RocketPoolRETHAddress != "" {
		lstMonitors["rETH"] = core.NewLSTMonitor("rETH", config.LSTMonitoring.RocketPoolRETHAddress, logger)
	}
	if config.LSTMonitoring.CoinbaseCBETHAddress != "" {
		lstMonitors["cbETH"] = core.NewLSTMonitor("cbETH", config.LSTMonitoring.CoinbaseCBETHAddress, logger)
	}
	if config.LSTMonitoring.FraxSFRXETHAddress != "" {
		lstMonitors["sfrxETH"] = core.NewLSTMonitor("sfrxETH", config.LSTMonitoring.FraxSFRXETHAddress, logger)
	}

	// Setup metrics
	metricsRegistry := prometheus.NewRegistry()
	challengerMetrics := metrics.NewChallengerMetrics(metricsRegistry)

	challenger := &EnhancedChallenger{
		config:                 config,
		logger:                 logger,
		ethClient:              ethClient,
		elClients:              elClients,
		elContracts:            elContracts,
		avsReader:              avsReader,
		avsWriter:              avsWriter,
		avsSubscriber:          avsSubscriber,
		operatorsInfoService:   operatorsInfoService,
		avsRegistryService:     avsRegistryService,
		lstMonitors:            lstMonitors,
		activeChallenges:       make(map[uint32]*types.ChallengeInfo),
		challengeHistory:       make(map[uint32]*types.ChallengeResult),
		challengeWindow:        CHALLENGE_WINDOW_BLOCKS * 12 * time.Second, // ~100 blocks * 12 seconds
		verifiedResponses:      make(map[uint32]bool),
		metricsRegistry:        metricsRegistry,
		metrics:                challengerMetrics,
		ctx:                    ctx,
		cancel:                 cancel,
	}

	return challenger, nil
}

// Start starts the enhanced challenger
func (c *EnhancedChallenger) Start(ctx context.Context) error {
	c.logger.Info("Starting Enhanced YieldSync Challenger")

	// Start operators info service
	if err := c.operatorsInfoService.Start(ctx); err != nil {
		return fmt.Errorf("failed to start operators info service: %w", err)
	}

	// Start LST monitors
	for name, monitor := range c.lstMonitors {
		c.logger.Info("Starting LST monitor", "lstToken", name)
		go monitor.Start(c.ctx, c.config.LSTMonitoring.MonitoringInterval)
	}

	// Start task response monitoring
	go c.monitorTaskResponses()

	// Start challenge processing
	go c.processChallenges()

	// Start expired challenge cleanup
	go c.cleanupExpiredChallenges()

	// Start metrics server
	go c.startMetricsServer()

	// Wait for context cancellation
	<-ctx.Done()

	c.logger.Info("Shutting down Enhanced YieldSync Challenger")
	return nil
}

// Stop stops the challenger
func (c *EnhancedChallenger) Stop() {
	c.logger.Info("Stopping Enhanced YieldSync Challenger")
	c.cancel()
}

// monitorTaskResponses monitors for new task responses to verify
func (c *EnhancedChallenger) monitorTaskResponses() {
	c.logger.Info("Starting task response monitoring for verification")

	// Subscribe to task response events
	taskResponseChan, err := c.avsSubscriber.SubscribeToTaskResponses()
	if err != nil {
		c.logger.Error("Failed to subscribe to task responses", "error", err)
		return
	}

	// Also periodically check for missed responses
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-c.ctx.Done():
			c.logger.Info("Task response monitoring stopped")
			return
		case taskResponse := <-taskResponseChan:
			if err := c.verifyTaskResponse(taskResponse); err != nil {
				c.logger.Error("Task response verification failed", "error", err)
			}
		case <-ticker.C:
			if err := c.checkForNewResponsesToVerify(); err != nil {
				c.logger.Error("Error checking for new responses", "error", err)
			}
		}
	}
}

// verifyTaskResponse verifies a task response and initiates challenge if needed
func (c *EnhancedChallenger) verifyTaskResponse(response *core.TaskResponseEvent) error {
	taskIndex := response.TaskIndex
	
	c.logger.Info("Verifying task response", "taskIndex", taskIndex)

	// Check if already verified
	c.verifiedResponsesMutex.RLock()
	if c.verifiedResponses[taskIndex] {
		c.verifiedResponsesMutex.RUnlock()
		return nil // Already verified
	}
	c.verifiedResponsesMutex.RUnlock()

	// Check if within challenge window
	if !c.isWithinChallengeWindow(response.TaskCreatedBlock) {
		c.logger.Debug("Task response outside challenge window", "taskIndex", taskIndex)
		return nil
	}

	// Get task details
	taskInfo, err := c.avsReader.GetTaskInfo(taskIndex)
	if err != nil {
		return fmt.Errorf("failed to get task info: %w", err)
	}

	// Verify the yield rate against actual LST protocol data
	isValid, actualYieldRate, err := c.verifyYieldRate(taskInfo.LSTToken, response.YieldRate, response.Timestamp)
	if err != nil {
		return fmt.Errorf("failed to verify yield rate: %w", err)
	}

	// Mark as verified
	c.verifiedResponsesMutex.Lock()
	c.verifiedResponses[taskIndex] = true
	c.verifiedResponsesMutex.Unlock()

	if !isValid {
		c.logger.Info("Invalid yield rate detected, initiating challenge",
			"taskIndex", taskIndex,
			"reportedRate", response.YieldRate,
			"actualRate", actualYieldRate)
		
		if err := c.initiateChallenge(taskIndex, response.YieldRate, actualYieldRate, taskInfo); err != nil {
			return fmt.Errorf("failed to initiate challenge: %w", err)
		}
	} else {
		c.logger.Debug("Task response verified as valid", "taskIndex", taskIndex)
		c.metrics.ResponsesVerified.Inc()
	}

	return nil
}

// verifyYieldRate verifies a reported yield rate against actual LST protocol data
func (c *EnhancedChallenger) verifyYieldRate(lstToken string, reportedRate uint32, timestamp time.Time) (bool, uint32, error) {
	monitor, exists := c.lstMonitors[lstToken]
	if !exists {
		return false, 0, fmt.Errorf("no monitor found for LST token %s", lstToken)
	}

	// Get actual yield data from the LST protocol
	actualYieldData, err := monitor.GetYieldDataAtTime(timestamp)
	if err != nil {
		// If we can't get historical data, use latest
		actualYieldData, err = monitor.GetLatestYieldData()
		if err != nil {
			return false, 0, fmt.Errorf("failed to get yield data: %w", err)
		}
		c.logger.Warn("Using latest yield data instead of historical",
			"lstToken", lstToken, "requestedTime", timestamp)
	}

	actualRate := actualYieldData.YieldRate

	// Check if the reported rate is within tolerance
	tolerance := uint32(YIELD_TOLERANCE_BPS)
	diff := uint32(math.Abs(float64(reportedRate) - float64(actualRate)))

	isValid := diff <= tolerance

	c.logger.Debug("Yield rate verification",
		"lstToken", lstToken,
		"reportedRate", reportedRate,
		"actualRate", actualRate,
		"difference", diff,
		"tolerance", tolerance,
		"isValid", isValid)

	return isValid, actualRate, nil
}

// initiateChallenge initiates a challenge for an incorrect task response
func (c *EnhancedChallenger) initiateChallenge(taskIndex, reportedRate, actualRate uint32, taskInfo *core.TaskInfo) error {
	c.logger.Info("Initiating challenge",
		"taskIndex", taskIndex,
		"reportedRate", reportedRate,
		"actualRate", actualRate)

	// Create challenge info
	challengeInfo := &types.ChallengeInfo{
		TaskIndex:    taskIndex,
		ChallengedAt: time.Now(),
		ReportedRate: reportedRate,
		ActualRate:   actualRate,
		Evidence:     c.generateEvidence(taskInfo.LSTToken, actualRate),
		Status:       types.ChallengePending,
	}

	// Store challenge info
	c.challengeMutex.Lock()
	c.activeChallenges[taskIndex] = challengeInfo
	c.challengeMutex.Unlock()

	// Submit challenge to contract
	if err := c.submitChallenge(taskIndex, challengeInfo); err != nil {
		c.challengeMutex.Lock()
		c.activeChallenges[taskIndex].Status = types.ChallengeFailed
		c.challengeMutex.Unlock()
		return fmt.Errorf("failed to submit challenge: %w", err)
	}

	// Update challenge status
	c.challengeMutex.Lock()
	c.activeChallenges[taskIndex].Status = types.ChallengeSubmitted
	c.challengeMutex.Unlock()

	// Update metrics
	c.metrics.ChallengesInitiated.Inc()

	c.logger.Info("Challenge submitted successfully", "taskIndex", taskIndex)
	return nil
}

// submitChallenge submits a challenge transaction to the contract
func (c *EnhancedChallenger) submitChallenge(taskIndex uint32, challengeInfo *types.ChallengeInfo) error {
	// Get current block number
	currentBlock, err := c.ethClient.BlockNumber(context.Background())
	if err != nil {
		return fmt.Errorf("failed to get current block number: %w", err)
	}

	// Create challenge data
	challengeData := &core.ChallengeData{
		TaskIndex:           taskIndex,
		ChallengedYieldRate: challengeInfo.ReportedRate,
		CorrectYieldRate:    challengeInfo.ActualRate,
		Evidence:            challengeInfo.Evidence,
		ChallengeBlock:      uint32(currentBlock),
	}

	// Submit via AVS writer
	challengeId, err := c.avsWriter.SubmitChallenge(challengeData)
	if err != nil {
		return fmt.Errorf("failed to submit challenge to contract: %w", err)
	}

	// Update challenge info with ID
	c.challengeMutex.Lock()
	challengeInfo.ChallengeId = challengeId
	challengeInfo.SubmittedBlock = uint32(currentBlock)
	c.challengeMutex.Unlock()

	c.logger.Info("Challenge submitted to contract",
		"taskIndex", taskIndex,
		"challengeId", challengeId,
		"block", currentBlock)

	return nil
}

// generateEvidence generates evidence for a challenge
func (c *EnhancedChallenger) generateEvidence(lstToken string, actualRate uint32) []byte {
	monitor, exists := c.lstMonitors[lstToken]
	if !exists {
		return []byte{}
	}

	// Generate evidence data - this could include:
	// - LST protocol contract state proofs
	// - Oracle price data
	// - Validator reward data
	evidence := map[string]interface{}{
		"lstToken":       lstToken,
		"actualRate":     actualRate,
		"timestamp":      time.Now().Unix(),
		"evidenceType":   "protocol_state",
		"protocolData":   monitor.GetProtocolEvidence(),
	}

	// Convert to JSON bytes
	evidenceBytes, _ := json.Marshal(evidence)
	return evidenceBytes
}

// processChallenges processes ongoing challenges
func (c *EnhancedChallenger) processChallenges() {
	c.logger.Info("Starting challenge processing")

	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-c.ctx.Done():
			c.logger.Info("Challenge processing stopped")
			return
		case <-ticker.C:
			c.checkChallengeStatuses()
		}
	}
}

// checkChallengeStatuses checks the status of ongoing challenges
func (c *EnhancedChallenger) checkChallengeStatuses() {
	c.challengeMutex.RLock()
	activeChallenges := make(map[uint32]*types.ChallengeInfo)
	for id, challenge := range c.activeChallenges {
		if challenge.Status == types.ChallengeSubmitted {
			activeChallenges[id] = challenge
		}
	}
	c.challengeMutex.RUnlock()

	for taskIndex, challengeInfo := range activeChallenges {
		status, err := c.avsReader.GetChallengeStatus(challengeInfo.ChallengeId)
		if err != nil {
			c.logger.Error("Failed to get challenge status",
				"taskIndex", taskIndex,
				"challengeId", challengeInfo.ChallengeId,
				"error", err)
			continue
		}

		if status != challengeInfo.Status {
			c.updateChallengeStatus(taskIndex, status)
		}
	}
}

// updateChallengeStatus updates the status of a challenge
func (c *EnhancedChallenger) updateChallengeStatus(taskIndex uint32, newStatus types.ChallengeStatus) {
	c.challengeMutex.Lock()
	defer c.challengeMutex.Unlock()

	challenge, exists := c.activeChallenges[taskIndex]
	if !exists {
		return
	}

	oldStatus := challenge.Status
	challenge.Status = newStatus

	c.logger.Info("Challenge status updated",
		"taskIndex", taskIndex,
		"oldStatus", oldStatus,
		"newStatus", newStatus)

	// Update metrics based on new status
	switch newStatus {
	case types.ChallengeSuccessful:
		c.metrics.ChallengesSuccessful.Inc()
		challenge.ResolvedAt = time.Now()
		challenge.Reward = big.NewInt(int64(CHALLENGE_REWARD_ETH * 1e18))
	case types.ChallengeFailed:
		c.metrics.ChallengesFailed.Inc()
		challenge.ResolvedAt = time.Now()
	}

	// Move to history if resolved
	if newStatus == types.ChallengeSuccessful || newStatus == types.ChallengeFailed {
		result := &types.ChallengeResult{
			TaskIndex:     taskIndex,
			ChallengeInfo: *challenge,
			Success:       newStatus == types.ChallengeSuccessful,
		}
		c.challengeHistory[taskIndex] = result
		delete(c.activeChallenges, taskIndex)
	}
}

// cleanupExpiredChallenges cleans up expired challenges
func (c *EnhancedChallenger) cleanupExpiredChallenges() {
	ticker := time.NewTicker(10 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-c.ctx.Done():
			return
		case <-ticker.C:
			c.performCleanup()
		}
	}
}

// performCleanup removes expired challenges and verified responses
func (c *EnhancedChallenger) performCleanup() {
	now := time.Now()
	expiredThreshold := now.Add(-24 * time.Hour) // Keep data for 24 hours

	// Clean up expired challenges
	c.challengeMutex.Lock()
	for taskIndex, challenge := range c.activeChallenges {
		if challenge.ChallengedAt.Before(expiredThreshold) {
			c.logger.Info("Cleaning up expired challenge", "taskIndex", taskIndex)
			delete(c.activeChallenges, taskIndex)
		}
	}
	c.challengeMutex.Unlock()

	// Clean up old verified responses
	c.verifiedResponsesMutex.Lock()
	// Note: In a real implementation, we'd need timestamps for verified responses
	// For now, we'll periodically clear the entire cache
	if len(c.verifiedResponses) > 10000 {
		c.verifiedResponses = make(map[uint32]bool)
		c.logger.Info("Cleared verified responses cache")
	}
	c.verifiedResponsesMutex.Unlock()

	c.logger.Debug("Performed cleanup", "timestamp", now)
}

// Helper methods

// isWithinChallengeWindow checks if a task is still within the challenge window
func (c *EnhancedChallenger) isWithinChallengeWindow(taskCreatedBlock uint32) bool {
	currentBlock, err := c.ethClient.BlockNumber(context.Background())
	if err != nil {
		c.logger.Error("Failed to get current block number", "error", err)
		return false
	}

	blocksSinceCreation := currentBlock - uint64(taskCreatedBlock)
	return blocksSinceCreation <= CHALLENGE_WINDOW_BLOCKS
}

// checkForNewResponsesToVerify checks for any missed task responses that need verification
func (c *EnhancedChallenger) checkForNewResponsesToVerify() error {
	// Get latest task responses from the contract
	latestResponses, err := c.avsReader.GetRecentTaskResponses(100) // Get last 100 responses
	if err != nil {
		return fmt.Errorf("failed to get recent task responses: %w", err)
	}

	for _, response := range latestResponses {
		// Check if we've already verified this response
		c.verifiedResponsesMutex.RLock()
		verified := c.verifiedResponses[response.TaskIndex]
		c.verifiedResponsesMutex.RUnlock()

		if !verified && c.isWithinChallengeWindow(response.TaskCreatedBlock) {
			if err := c.verifyTaskResponse(response); err != nil {
				c.logger.Error("Failed to verify task response",
					"taskIndex", response.TaskIndex, "error", err)
			}
		}
	}

	return nil
}

// startMetricsServer starts the metrics server
func (c *EnhancedChallenger) startMetricsServer() {
	if c.config.Challenger.EnableMetrics {
		http.Handle("/metrics", promhttp.HandlerFor(c.metricsRegistry, promhttp.HandlerOpts{}))
		
		c.logger.Info("Starting challenger metrics server", 
			"addr", c.config.Challenger.MetricsIpPortAddr)
		
		if err := http.ListenAndServe(c.config.Challenger.MetricsIpPortAddr, nil); err != nil {
			c.logger.Error("Challenger metrics server error", "error", err)
		}
	}
}

// Public query methods

// GetActiveChallenges returns all active challenges
func (c *EnhancedChallenger) GetActiveChallenges() map[uint32]*types.ChallengeInfo {
	c.challengeMutex.RLock()
	defer c.challengeMutex.RUnlock()
	
	result := make(map[uint32]*types.ChallengeInfo)
	for id, challenge := range c.activeChallenges {
		challengeCopy := *challenge
		result[id] = &challengeCopy
	}
	return result
}

// GetChallengeHistory returns challenge history
func (c *EnhancedChallenger) GetChallengeHistory() map[uint32]*types.ChallengeResult {
	c.challengeMutex.RLock()
	defer c.challengeMutex.RUnlock()
	
	result := make(map[uint32]*types.ChallengeResult)
	for id, result := range c.challengeHistory {
		resultCopy := *result
		result[id] = &resultCopy
	}
	return result
}

// GetChallengeStats returns challenge statistics
func (c *EnhancedChallenger) GetChallengeStats() *types.ChallengeStats {
	c.challengeMutex.RLock()
	defer c.challengeMutex.RUnlock()

	stats := &types.ChallengeStats{
		ActiveChallenges:    len(c.activeChallenges),
		TotalChallenges:     len(c.challengeHistory),
		SuccessfulChallenges: 0,
		FailedChallenges:    0,
	}

	for _, result := range c.challengeHistory {
		if result.Success {
			stats.SuccessfulChallenges++
		} else {
			stats.FailedChallenges++
		}
	}

	return stats
}