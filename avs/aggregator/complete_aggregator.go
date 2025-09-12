package aggregator

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"sort"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"golang.org/x/crypto/sha3"

	"github.com/Layr-Labs/eigensdk-go/chainio/clients"
	"github.com/Layr-Labs/eigensdk-go/chainio/clients/eth"
	sdkcontracts "github.com/Layr-Labs/eigensdk-go/chainio/clients/elcontracts"
	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	sdklogging "github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/Layr-Labs/eigensdk-go/services/avsregistry"
	blsagg "github.com/Layr-Labs/eigensdk-go/services/bls_aggregation"
	"github.com/Layr-Labs/eigensdk-go/services/operatorsinfo"
	sdktypes "github.com/Layr-Labs/eigensdk-go/types"

	"github.com/YieldSync/yieldsync-hook/avs/aggregator/types"
	"github.com/YieldSync/yieldsync-hook/avs/core"
	"github.com/YieldSync/yieldsync-hook/avs/metrics"
)

const (
	AVS_NAME = "yieldsync"
	SEM_VER  = "0.1.0"
)

// Enhanced Aggregator with complete BLS aggregation and task management
type EnhancedAggregator struct {
	config    core.NodeConfig
	logger    sdklogging.Logger
	ethClient eth.Client

	// EigenLayer services
	elClients             *clients.Clients
	elContracts           *sdkcontracts.Clients
	avsReader            core.AvsReaderer
	avsWriter            core.AvsWriter
	avsSubscriber        core.AvsSubscriberer
	blsAggregationService blsagg.BlsAggregationService
	operatorsInfoService  operatorsinfo.OperatorsInfoService
	avsRegistryService   avsregistry.AvsRegistryService

	// Task and response management
	taskMutex           sync.RWMutex
	pendingTasks        map[uint32]*types.TaskInfo
	taskResponses       map[uint32]map[sdktypes.OperatorId]*types.SignedTaskResponse
	quorumThreshold     map[uint8]sdktypes.ThresholdPercentage

	// Metrics and monitoring
	metricsRegistry *prometheus.Registry
	metrics         *metrics.AggregatorMetrics
	httpServer      *http.Server

	// Context and cancellation
	ctx    context.Context
	cancel context.CancelFunc
}

// NewEnhancedAggregator creates a new enhanced aggregator with complete functionality
func NewEnhancedAggregator(config core.NodeConfig) (*EnhancedAggregator, error) {
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
		common.HexToAddress(config.Aggregator.AggregatorAddress),
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
		common.HexToAddress(config.Aggregator.AggregatorAddress),
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

	// Setup BLS aggregation service
	blsAggregationService := blsagg.NewBlsAggregationService(
		elClients.AvsRegistryCoordinator,
		logger,
	)

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

	// Setup metrics
	metricsRegistry := prometheus.NewRegistry()
	aggregatorMetrics := metrics.NewAggregatorMetrics(metricsRegistry)

	// Initialize quorum thresholds
	quorumThreshold := make(map[uint8]sdktypes.ThresholdPercentage)
	quorumThreshold[0] = sdktypes.ThresholdPercentage(config.Aggregator.QuorumThresholdPercentage)

	aggregator := &EnhancedAggregator{
		config:                config,
		logger:                logger,
		ethClient:             ethClient,
		elClients:             elClients,
		elContracts:           elContracts,
		avsReader:             avsReader,
		avsWriter:             avsWriter,
		avsSubscriber:         avsSubscriber,
		blsAggregationService: blsAggregationService,
		operatorsInfoService:  operatorsInfoService,
		avsRegistryService:    avsRegistryService,
		pendingTasks:          make(map[uint32]*types.TaskInfo),
		taskResponses:         make(map[uint32]map[sdktypes.OperatorId]*types.SignedTaskResponse),
		quorumThreshold:       quorumThreshold,
		metricsRegistry:       metricsRegistry,
		metrics:               aggregatorMetrics,
		ctx:                   ctx,
		cancel:                cancel,
	}

	return aggregator, nil
}

// Start starts the enhanced aggregator
func (a *EnhancedAggregator) Start(ctx context.Context) error {
	a.logger.Info("Starting Enhanced YieldSync Aggregator")

	// Start operators info service
	if err := a.operatorsInfoService.Start(ctx); err != nil {
		return fmt.Errorf("failed to start operators info service: %w", err)
	}

	// Start BLS aggregation service
	if err := a.blsAggregationService.Start(ctx); err != nil {
		return fmt.Errorf("failed to start bls aggregation service: %w", err)
	}

	// Start HTTP server for operator communication
	go a.startHttpServer()

	// Start task creation loop
	go a.taskCreationLoop()

	// Start task response monitoring
	go a.monitorTaskResponses()

	// Start metrics server
	go a.startMetricsServer()

	// Wait for context cancellation
	<-ctx.Done()

	a.logger.Info("Shutting down Enhanced YieldSync Aggregator")
	return nil
}

// Stop stops the aggregator
func (a *EnhancedAggregator) Stop() {
	a.logger.Info("Stopping Enhanced YieldSync Aggregator")
	if a.httpServer != nil {
		a.httpServer.Shutdown(context.Background())
	}
	a.cancel()
}

// CreateNewTask creates a new yield monitoring task
func (a *EnhancedAggregator) CreateNewTask(lstToken string, quorumNumbers sdktypes.QuorumNums, quorumThresholdPercentages []sdktypes.ThresholdPercentage) (*types.TaskInfo, error) {
	a.logger.Info("Creating new task", "lstToken", lstToken, "quorumNumbers", quorumNumbers)

	// Get current block number
	currentBlock, err := a.ethClient.BlockNumber(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get current block number: %w", err)
	}

	// Create task
	task := &types.TaskInfo{
		LSTToken:                   lstToken,
		TaskCreatedBlock:           uint32(currentBlock),
		QuorumNumbers:              quorumNumbers,
		QuorumThresholdPercentages: quorumThresholdPercentages,
		TaskCreatedTime:            time.Now(),
		TaskResponseDeadline:       time.Now().Add(10 * time.Minute),
	}

	// Submit task to contract via AVS writer
	taskIndex, err := a.avsWriter.CreateNewTask(lstToken, quorumNumbers, quorumThresholdPercentages)
	if err != nil {
		return nil, fmt.Errorf("failed to submit task to contract: %w", err)
	}

	task.TaskIndex = taskIndex

	// Store task in pending tasks
	a.taskMutex.Lock()
	a.pendingTasks[taskIndex] = task
	a.taskResponses[taskIndex] = make(map[sdktypes.OperatorId]*types.SignedTaskResponse)
	a.taskMutex.Unlock()

	// Update metrics
	a.metrics.TasksCreated.Inc()

	a.logger.Info("Task created successfully", "taskIndex", taskIndex, "lstToken", lstToken)
	return task, nil
}

// taskCreationLoop periodically creates new yield monitoring tasks
func (a *EnhancedAggregator) taskCreationLoop() {
	a.logger.Info("Starting task creation loop")

	// Create tasks for different LST tokens every 30 seconds
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	lstTokens := []string{"stETH", "rETH", "cbETH", "sfrxETH"}
	tokenIndex := 0

	for {
		select {
		case <-a.ctx.Done():
			a.logger.Info("Task creation loop stopped")
			return
		case <-ticker.C:
			// Create task for current LST token
			lstToken := lstTokens[tokenIndex]
			quorumNumbers := sdktypes.QuorumNums{0} // Single quorum
			quorumThresholdPercentages := []sdktypes.ThresholdPercentage{67} // 67% threshold

			task, err := a.CreateNewTask(lstToken, quorumNumbers, quorumThresholdPercentages)
			if err != nil {
				a.logger.Error("Failed to create task", "lstToken", lstToken, "error", err)
			} else {
				a.logger.Info("Created task", "taskIndex", task.TaskIndex, "lstToken", lstToken)
			}

			// Move to next LST token
			tokenIndex = (tokenIndex + 1) % len(lstTokens)
		}
	}
}

// monitorTaskResponses monitors for task responses from operators
func (a *EnhancedAggregator) monitorTaskResponses() {
	a.logger.Info("Starting task response monitoring")

	// Subscribe to task response events
	taskResponseChan, err := a.avsSubscriber.SubscribeToTaskResponses()
	if err != nil {
		a.logger.Error("Failed to subscribe to task responses", "error", err)
		return
	}

	// Also check for expired tasks
	expiredTaskTicker := time.NewTicker(30 * time.Second)
	defer expiredTaskTicker.Stop()

	for {
		select {
		case <-a.ctx.Done():
			a.logger.Info("Task response monitoring stopped")
			return
		case taskResponse := <-taskResponseChan:
			if err := a.processTaskResponse(taskResponse); err != nil {
				a.logger.Error("Failed to process task response", "error", err)
			}
		case <-expiredTaskTicker.C:
			a.checkExpiredTasks()
		}
	}
}

// processTaskResponse processes a task response from an operator
func (a *EnhancedAggregator) processTaskResponse(response *types.SignedTaskResponse) error {
	a.logger.Info("Processing task response", "taskIndex", response.TaskResponse.ReferenceTaskIndex, "operatorId", response.OperatorId.Hex())

	// Verify the response is for a valid task
	a.taskMutex.RLock()
	taskInfo, exists := a.pendingTasks[response.TaskResponse.ReferenceTaskIndex]
	a.taskMutex.RUnlock()

	if !exists {
		return fmt.Errorf("received response for unknown task %d", response.TaskResponse.ReferenceTaskIndex)
	}

	// Check if task response deadline has passed
	if time.Now().After(taskInfo.TaskResponseDeadline) {
		a.logger.Warn("Received response for expired task", "taskIndex", response.TaskResponse.ReferenceTaskIndex)
		return fmt.Errorf("task response deadline passed")
	}

	// Verify the operator signature
	if err := a.verifyTaskResponse(response); err != nil {
		return fmt.Errorf("task response verification failed: %w", err)
	}

	// Store the response
	a.taskMutex.Lock()
	a.taskResponses[response.TaskResponse.ReferenceTaskIndex][response.OperatorId] = response
	a.taskMutex.Unlock()

	// Update metrics
	a.metrics.ResponsesReceived.Inc()

	// Check if we have enough responses to aggregate
	if err := a.tryAggregateResponses(response.TaskResponse.ReferenceTaskIndex); err != nil {
		a.logger.Error("Failed to aggregate responses", "taskIndex", response.TaskResponse.ReferenceTaskIndex, "error", err)
		return err
	}

	return nil
}

// tryAggregateResponses tries to aggregate responses if we have sufficient quorum
func (a *EnhancedAggregator) tryAggregateResponses(taskIndex uint32) error {
	a.taskMutex.RLock()
	taskInfo := a.pendingTasks[taskIndex]
	responses := a.taskResponses[taskIndex]
	a.taskMutex.RUnlock()

	if taskInfo == nil {
		return fmt.Errorf("task info not found for task %d", taskIndex)
	}

	// Check if we have enough responses for each quorum
	for i, quorumNumber := range taskInfo.QuorumNumbers {
		threshold := taskInfo.QuorumThresholdPercentages[i]
		
		// Get operators for this quorum
		operatorsInQuorum, err := a.getOperatorsInQuorum(quorumNumber)
		if err != nil {
			a.logger.Error("Failed to get operators in quorum", "quorumNumber", quorumNumber, "error", err)
			continue
		}

		// Count responses from operators in this quorum
		responsesInQuorum := 0
		for operatorId := range responses {
			if a.operatorInQuorum(operatorId, operatorsInQuorum) {
				responsesInQuorum++
			}
		}

		// Check if we have enough responses
		requiredResponses := (len(operatorsInQuorum) * int(threshold)) / 100
		if responsesInQuorum < requiredResponses {
			a.logger.Debug("Not enough responses for quorum", 
				"taskIndex", taskIndex,
				"quorumNumber", quorumNumber,
				"responsesInQuorum", responsesInQuorum,
				"requiredResponses", requiredResponses)
			return nil // Not enough responses yet
		}
	}

	// We have enough responses, aggregate them
	return a.aggregateAndSubmitResponses(taskIndex)
}

// aggregateAndSubmitResponses aggregates responses and submits to contract
func (a *EnhancedAggregator) aggregateAndSubmitResponses(taskIndex uint32) error {
	a.logger.Info("Aggregating and submitting responses", "taskIndex", taskIndex)

	a.taskMutex.RLock()
	taskInfo := a.pendingTasks[taskIndex]
	responses := make(map[sdktypes.OperatorId]*types.SignedTaskResponse)
	for operatorId, response := range a.taskResponses[taskIndex] {
		responses[operatorId] = response
	}
	a.taskMutex.RUnlock()

	// Calculate consensus yield rate (simple majority for now)
	yieldRates := make([]uint32, 0, len(responses))
	for _, response := range responses {
		yieldRates = append(yieldRates, response.TaskResponse.YieldRate)
	}
	consensusYieldRate := a.calculateConsensusYieldRate(yieldRates)

	// Create aggregated task response
	aggregatedResponse := &types.TaskResponse{
		ReferenceTaskIndex: taskIndex,
		YieldRate:          consensusYieldRate,
		Timestamp:          time.Now(),
		DataHash:           a.createResponseDataHash(taskInfo.LSTToken, consensusYieldRate),
	}

	// Aggregate BLS signatures
	signatures := make([]*bls.Signature, 0, len(responses))
	signers := make([]sdktypes.OperatorId, 0, len(responses))
	for operatorId, response := range responses {
		signatures = append(signatures, response.BlsSignature)
		signers = append(signers, operatorId)
	}

	aggregatedSignature, err := a.blsAggregationService.AggregateSignatures(
		context.Background(),
		taskIndex,
		a.createTaskResponseHash(aggregatedResponse),
		signers,
		signatures,
	)
	if err != nil {
		return fmt.Errorf("failed to aggregate signatures: %w", err)
	}

	// Submit to contract
	if err := a.avsWriter.SendAggregatedResponse(aggregatedResponse, aggregatedSignature); err != nil {
		return fmt.Errorf("failed to submit aggregated response: %w", err)
	}

	// Clean up task
	a.taskMutex.Lock()
	delete(a.pendingTasks, taskIndex)
	delete(a.taskResponses, taskIndex)
	a.taskMutex.Unlock()

	// Update metrics
	a.metrics.ResponsesAggregated.Inc()

	a.logger.Info("Successfully aggregated and submitted responses", 
		"taskIndex", taskIndex,
		"consensusYieldRate", consensusYieldRate,
		"numResponses", len(responses))

	return nil
}

// verifyTaskResponse verifies a task response signature and content
func (a *EnhancedAggregator) verifyTaskResponse(response *types.SignedTaskResponse) error {
	// Verify operator is registered
	operatorInfo, err := a.operatorsInfoService.GetOperatorInfo(context.Background(), response.OperatorId)
	if err != nil {
		return fmt.Errorf("failed to get operator info: %w", err)
	}

	// Create message hash for signature verification
	messageHash := a.createTaskResponseHash(response.TaskResponse)

	// Verify BLS signature
	if err := response.BlsSignature.Verify(operatorInfo.Pubkeys.G1Pubkey, messageHash); err != nil {
		return fmt.Errorf("BLS signature verification failed: %w", err)
	}

	// Verify yield rate is reasonable (basic sanity check)
	if response.TaskResponse.YieldRate > 10000 { // 100% max yield rate
		return fmt.Errorf("yield rate too high: %d", response.TaskResponse.YieldRate)
	}

	return nil
}

// checkExpiredTasks checks for expired tasks and cleans them up
func (a *EnhancedAggregator) checkExpiredTasks() {
	a.taskMutex.Lock()
	defer a.taskMutex.Unlock()

	expiredTasks := make([]uint32, 0)
	for taskIndex, taskInfo := range a.pendingTasks {
		if time.Now().After(taskInfo.TaskResponseDeadline) {
			expiredTasks = append(expiredTasks, taskIndex)
		}
	}

	for _, taskIndex := range expiredTasks {
		a.logger.Info("Cleaning up expired task", "taskIndex", taskIndex)
		delete(a.pendingTasks, taskIndex)
		delete(a.taskResponses, taskIndex)
		a.metrics.TasksExpired.Inc()
	}

	if len(expiredTasks) > 0 {
		a.logger.Info("Cleaned up expired tasks", "count", len(expiredTasks))
	}
}

// Helper methods

// getOperatorsInQuorum gets all operators in a specific quorum
func (a *EnhancedAggregator) getOperatorsInQuorum(quorumNumber uint8) ([]sdktypes.OperatorId, error) {
	// This would query the registry to get operators in the quorum
	// For now, return a mock list
	return []sdktypes.OperatorId{}, nil
}

// operatorInQuorum checks if an operator is in a specific quorum
func (a *EnhancedAggregator) operatorInQuorum(operatorId sdktypes.OperatorId, operatorsInQuorum []sdktypes.OperatorId) bool {
	for _, id := range operatorsInQuorum {
		if id == operatorId {
			return true
		}
	}
	return false
}

// calculateConsensusYieldRate calculates consensus yield rate from multiple responses
func (a *EnhancedAggregator) calculateConsensusYieldRate(yieldRates []uint32) uint32 {
	if len(yieldRates) == 0 {
		return 0
	}

	// Sort yield rates and return median
	sort.Slice(yieldRates, func(i, j int) bool {
		return yieldRates[i] < yieldRates[j]
	})

	if len(yieldRates)%2 == 0 {
		return (yieldRates[len(yieldRates)/2-1] + yieldRates[len(yieldRates)/2]) / 2
	}
	return yieldRates[len(yieldRates)/2]
}

// createTaskResponseHash creates a hash of the task response for signing
func (a *EnhancedAggregator) createTaskResponseHash(taskResponse *types.TaskResponse) [32]byte {
	// This should match the hash function used in the smart contract
	data := fmt.Sprintf("%d:%d:%d:%s", 
		taskResponse.ReferenceTaskIndex,
		taskResponse.YieldRate,
		taskResponse.Timestamp.Unix(),
		taskResponse.DataHash,
	)
	hash := sha3.NewLegacyKeccak256()
	hash.Write([]byte(data))
	var result [32]byte
	copy(result[:], hash.Sum(nil))
	return result
}

// createResponseDataHash creates a hash for response data
func (a *EnhancedAggregator) createResponseDataHash(lstToken string, yieldRate uint32) string {
	data := fmt.Sprintf("%s:%d:%d", lstToken, yieldRate, time.Now().Unix())
	hash := sha3.NewLegacyKeccak256()
	hash.Write([]byte(data))
	return fmt.Sprintf("0x%x", hash.Sum(nil))
}

// startHttpServer starts the HTTP server for operator communication
func (a *EnhancedAggregator) startHttpServer() {
	router := mux.NewRouter()

	// Health check endpoint
	router.HandleFunc("/health", a.healthCheckHandler).Methods("GET")
	
	// Task submission endpoint for operators
	router.HandleFunc("/tasks/{taskIndex}/responses", a.submitTaskResponseHandler).Methods("POST")
	
	// Get pending tasks endpoint
	router.HandleFunc("/tasks/pending", a.getPendingTasksHandler).Methods("GET")
	
	// Metrics endpoint
	router.Handle("/metrics", promhttp.HandlerFor(a.metricsRegistry, promhttp.HandlerOpts{}))

	a.httpServer = &http.Server{
		Addr:    a.config.Aggregator.ServerIpPortAddr,
		Handler: router,
	}

	a.logger.Info("Starting HTTP server", "addr", a.config.Aggregator.ServerIpPortAddr)
	if err := a.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		a.logger.Error("HTTP server error", "error", err)
	}
}

// startMetricsServer starts the metrics server
func (a *EnhancedAggregator) startMetricsServer() {
	if a.config.Aggregator.EnableMetrics {
		metricsRouter := mux.NewRouter()
		metricsRouter.Handle("/metrics", promhttp.HandlerFor(a.metricsRegistry, promhttp.HandlerOpts{}))
		
		metricsServer := &http.Server{
			Addr:    a.config.Aggregator.MetricsIpPortAddr,
			Handler: metricsRouter,
		}

		a.logger.Info("Starting metrics server", "addr", a.config.Aggregator.MetricsIpPortAddr)
		if err := metricsServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			a.logger.Error("Metrics server error", "error", err)
		}
	}
}

// HTTP handlers

func (a *EnhancedAggregator) healthCheckHandler(w http.ResponseWriter, r *http.Request) {
	response := types.HealthCheckResponse{
		Status:    "healthy",
		Timestamp: time.Now(),
		Uptime:    time.Since(time.Now()).String(), // This would be actual uptime
		Version:   SEM_VER,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (a *EnhancedAggregator) submitTaskResponseHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	taskIndex := vars["taskIndex"]

	var response types.SignedTaskResponse
	if err := json.NewDecoder(r.Body).Decode(&response); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if err := a.processTaskResponse(&response); err != nil {
		a.logger.Error("Failed to process task response", "error", err)
		http.Error(w, "Failed to process response", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

func (a *EnhancedAggregator) getPendingTasksHandler(w http.ResponseWriter, r *http.Request) {
	a.taskMutex.RLock()
	pendingTasks := make([]*types.TaskInfo, 0, len(a.pendingTasks))
	for _, task := range a.pendingTasks {
		pendingTasks = append(pendingTasks, task)
	}
	a.taskMutex.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(pendingTasks)
}