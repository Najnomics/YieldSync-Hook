package operator

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
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
	"github.com/Layr-Labs/eigensdk-go/chainio/clients/wallet"
	sdkcontracts "github.com/Layr-Labs/eigensdk-go/chainio/clients/elcontracts"
	"github.com/Layr-Labs/eigensdk-go/chainio/txmgr"
	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	sdkecdsa "github.com/Layr-Labs/eigensdk-go/crypto/ecdsa"
	sdklogging "github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/Layr-Labs/eigensdk-go/nodeapi"
	"github.com/Layr-Labs/eigensdk-go/services/operatorsinfo"
	"github.com/Layr-Labs/eigensdk-go/signerv2"
	sdktypes "github.com/Layr-Labs/eigensdk-go/types"

	"github.com/YieldSync/yieldsync-hook/avs/core"
	"github.com/YieldSync/yieldsync-hook/avs/metrics"
	"github.com/YieldSync/yieldsync-hook/avs/operator/types"
)

const (
	AVS_NAME = "yieldsync"
	SEM_VER  = "0.1.0"
)

// EnhancedOperator represents a complete YieldSync operator implementation
type EnhancedOperator struct {
	config    core.NodeConfig
	logger    sdklogging.Logger
	ethClient eth.Client

	// EigenLayer clients
	elClients       *clients.Clients
	elContracts     *sdkcontracts.Clients
	avsReader      core.AvsReaderer
	avsWriter      core.AvsWriter
	avsSubscriber  core.AvsSubscriberer

	// Crypto components
	operatorId      sdktypes.OperatorId
	operatorAddr    common.Address
	blsKeypair     *bls.KeyPair
	operatorSigner  signerv2.SignerV2

	// LST monitoring
	lstMonitors    map[string]*core.LSTMonitor
	monitoringLock sync.RWMutex

	// Task management
	pendingTasks      map[uint32]*types.TaskInfo
	taskResponses     map[uint32]*types.TaskResponseData
	taskMutex         sync.RWMutex
	aggregatorClient  *http.Client

	// Metrics and monitoring
	metricsRegistry *prometheus.Registry
	metrics         *metrics.OperatorMetrics
	nodeApi         *nodeapi.NodeApi

	// HTTP server
	httpServer *http.Server

	// Context and cancellation
	ctx    context.Context
	cancel context.CancelFunc
}

// NewEnhancedOperator creates a new enhanced operator
func NewEnhancedOperator(config core.NodeConfig) (*EnhancedOperator, error) {
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

	// Setup crypto components
	ecdsaKeyPair, err := sdkecdsa.ReadKey(config.EigenLayer.EcdsaPrivateKeyStorePath)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to read ecdsa key: %w", err)
	}

	blsKeyPair, err := bls.ReadPrivateKeyFromFile(config.EigenLayer.BlsPrivateKeyStorePath)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to read bls key: %w", err)
	}

	operatorAddr := common.HexToAddress(config.EigenLayer.OperatorAddress)

	// Setup wallet and signer
	signerConfig := signerv2.Config{
		PrivateKey: ecdsaKeyPair,
		Address:    operatorAddr,
	}
	operatorSigner, err := signerv2.NewSignerV2(signerConfig, ethClient, logger)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create signer: %w", err)
	}

	// Setup EigenLayer clients
	elClients, err := clients.NewClients(
		config.EthRpcUrl,
		config.EthWsUrl,
		operatorAddr,
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

	// Get operator ID
	operatorId, err := elClients.AvsRegistryCoordinator.GetOperatorId(&bind.CallOpts{}, operatorAddr)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to get operator id: %w", err)
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
		operatorAddr,
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

	// Setup LST monitors
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
	operatorMetrics := metrics.NewOperatorMetrics(metricsRegistry)

	// Setup Node API
	nodeApi := nodeapi.NewNodeApi(AVS_NAME, SEM_VER, config.Operator.NodeApiIpPortAddr, logger)

	// Setup aggregator client
	aggregatorClient := &http.Client{
		Timeout: 30 * time.Second,
	}

	operator := &EnhancedOperator{
		config:           config,
		logger:           logger,
		ethClient:        ethClient,
		elClients:        elClients,
		elContracts:      elContracts,
		avsReader:        avsReader,
		avsWriter:        avsWriter,
		avsSubscriber:    avsSubscriber,
		operatorId:       operatorId,
		operatorAddr:     operatorAddr,
		blsKeypair:       blsKeyPair,
		operatorSigner:   operatorSigner,
		lstMonitors:      lstMonitors,
		pendingTasks:     make(map[uint32]*types.TaskInfo),
		taskResponses:    make(map[uint32]*types.TaskResponseData),
		metricsRegistry:  metricsRegistry,
		metrics:          operatorMetrics,
		nodeApi:          nodeApi,
		aggregatorClient: aggregatorClient,
		ctx:              ctx,
		cancel:           cancel,
	}

	return operator, nil
}

// Start starts the enhanced operator
func (o *EnhancedOperator) Start(ctx context.Context) error {
	o.logger.Info("Starting Enhanced YieldSync Operator",
		"operatorAddress", o.operatorAddr.Hex(),
		"operatorId", o.operatorId.Hex())

	// Start LST monitors
	for name, monitor := range o.lstMonitors {
		o.logger.Info("Starting LST monitor", "lstToken", name)
		go monitor.Start(o.ctx, o.config.LSTMonitoring.MonitoringInterval)
	}

	// Start task monitoring
	go o.monitorTasks()

	// Start task processing
	go o.processTasks()

	// Start HTTP server
	go o.startHttpServer()

	// Start metrics server
	go o.startMetricsServer()

	// Start node API
	if o.config.Operator.EnableNodeApi {
		go o.nodeApi.Start()
	}

	// Start health monitoring
	go o.healthMonitor()

	// Wait for context cancellation
	<-ctx.Done()

	o.logger.Info("Shutting down Enhanced YieldSync Operator")
	return nil
}

// Stop stops the operator
func (o *EnhancedOperator) Stop() {
	o.logger.Info("Stopping Enhanced YieldSync Operator")
	if o.httpServer != nil {
		o.httpServer.Shutdown(context.Background())
	}
	if o.nodeApi != nil {
		o.nodeApi.Shutdown()
	}
	o.cancel()
}

// monitorTasks monitors for new tasks from the aggregator
func (o *EnhancedOperator) monitorTasks() {
	o.logger.Info("Starting task monitoring")

	// Subscribe to new task events
	taskCreatedChan, err := o.avsSubscriber.SubscribeToNewTasks()
	if err != nil {
		o.logger.Error("Failed to subscribe to new tasks", "error", err)
		return
	}

	for {
		select {
		case <-o.ctx.Done():
			o.logger.Info("Task monitoring stopped")
			return
		case task := <-taskCreatedChan:
			if err := o.handleNewTask(task); err != nil {
				o.logger.Error("Failed to handle new task", "error", err)
			}
		}
	}
}

// handleNewTask handles a new task from the aggregator
func (o *EnhancedOperator) handleNewTask(task *core.NewTaskEvent) error {
	o.logger.Info("Received new task",
		"taskIndex", task.TaskIndex,
		"lstToken", task.LSTToken)

	// Store task info
	taskInfo := &types.TaskInfo{
		TaskIndex:        task.TaskIndex,
		LSTToken:         task.LSTToken,
		TaskCreatedBlock: task.TaskCreatedBlock,
		QuorumNumbers:    task.QuorumNumbers,
		ReceivedAt:       time.Now(),
		DeadlineAt:       time.Now().Add(8 * time.Minute), // 8 min to respond
	}

	o.taskMutex.Lock()
	o.pendingTasks[task.TaskIndex] = taskInfo
	o.taskMutex.Unlock()

	o.metrics.TasksReceived.Inc()
	return nil
}

// processTasks processes pending tasks
func (o *EnhancedOperator) processTasks() {
	o.logger.Info("Starting task processing")

	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-o.ctx.Done():
			o.logger.Info("Task processing stopped")
			return
		case <-ticker.C:
			o.processAllPendingTasks()
		}
	}
}

// processAllPendingTasks processes all pending tasks
func (o *EnhancedOperator) processAllPendingTasks() {
	o.taskMutex.RLock()
	tasks := make([]*types.TaskInfo, 0, len(o.pendingTasks))
	for _, task := range o.pendingTasks {
		if time.Now().Before(task.DeadlineAt) {
			tasks = append(tasks, task)
		}
	}
	o.taskMutex.RUnlock()

	for _, task := range tasks {
		if err := o.processTask(task); err != nil {
			o.logger.Error("Failed to process task",
				"taskIndex", task.TaskIndex,
				"error", err)
		}
	}
}

// processTask processes a single task
func (o *EnhancedOperator) processTask(task *types.TaskInfo) error {
	// Check if already processed
	o.taskMutex.RLock()
	_, alreadyProcessed := o.taskResponses[task.TaskIndex]
	o.taskMutex.RUnlock()
	
	if alreadyProcessed {
		return nil
	}

	o.logger.Info("Processing task",
		"taskIndex", task.TaskIndex,
		"lstToken", task.LSTToken)

	// Get yield data from LST monitor
	monitor, exists := o.lstMonitors[task.LSTToken]
	if !exists {
		return fmt.Errorf("no monitor found for LST token %s", task.LSTToken)
	}

	yieldData, err := monitor.GetLatestYieldData()
	if err != nil {
		return fmt.Errorf("failed to get yield data: %w", err)
	}

	// Create task response
	response := &types.TaskResponse{
		ReferenceTaskIndex: task.TaskIndex,
		YieldRate:          yieldData.YieldRate,
		Timestamp:          time.Now(),
		DataHash:           o.createResponseDataHash(task.LSTToken, yieldData.YieldRate),
	}

	// Sign the response
	signature, err := o.signTaskResponse(response)
	if err != nil {
		return fmt.Errorf("failed to sign task response: %w", err)
	}

	// Create signed response
	signedResponse := &types.SignedTaskResponse{
		TaskResponse: response,
		BlsSignature: signature,
		OperatorId:   o.operatorId,
	}

	// Store response
	responseData := &types.TaskResponseData{
		TaskInfo:         task,
		SignedResponse:   signedResponse,
		ProcessedAt:      time.Now(),
		SubmissionStatus: types.StatusPending,
	}

	o.taskMutex.Lock()
	o.taskResponses[task.TaskIndex] = responseData
	o.taskMutex.Unlock()

	// Submit to aggregator
	if err := o.submitResponseToAggregator(signedResponse); err != nil {
		o.logger.Error("Failed to submit response to aggregator",
			"taskIndex", task.TaskIndex,
			"error", err)
		
		o.taskMutex.Lock()
		responseData.SubmissionStatus = types.StatusFailed
		responseData.Error = err.Error()
		o.taskMutex.Unlock()
		
		o.metrics.ResponsesFailedSubmission.Inc()
		return err
	}

	// Update status
	o.taskMutex.Lock()
	responseData.SubmissionStatus = types.StatusSubmitted
	o.taskMutex.Unlock()

	// Remove from pending tasks
	o.taskMutex.Lock()
	delete(o.pendingTasks, task.TaskIndex)
	o.taskMutex.Unlock()

	o.metrics.ResponsesSubmitted.Inc()
	o.logger.Info("Task response submitted successfully",
		"taskIndex", task.TaskIndex,
		"yieldRate", yieldData.YieldRate)

	return nil
}

// signTaskResponse signs a task response with BLS signature
func (o *EnhancedOperator) signTaskResponse(response *types.TaskResponse) (*bls.Signature, error) {
	// Create message hash
	messageHash := o.createTaskResponseHash(response)

	// Sign with BLS key
	signature := o.blsKeypair.SignMessage(messageHash)
	
	return signature, nil
}

// submitResponseToAggregator submits a task response to the aggregator
func (o *EnhancedOperator) submitResponseToAggregator(response *types.SignedTaskResponse) error {
	url := fmt.Sprintf("%s/tasks/%d/responses", 
		o.config.Aggregator.ServerIpPortAddr, 
		response.TaskResponse.ReferenceTaskIndex)

	jsonData, err := json.Marshal(response)
	if err != nil {
		return fmt.Errorf("failed to marshal response: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := o.aggregatorClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to submit response: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("aggregator returned status %d", resp.StatusCode)
	}

	return nil
}

// healthMonitor monitors operator health
func (o *EnhancedOperator) healthMonitor() {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-o.ctx.Done():
			return
		case <-ticker.C:
			o.performHealthCheck()
		}
	}
}

// performHealthCheck performs health checks and updates metrics
func (o *EnhancedOperator) performHealthCheck() {
	// Check LST monitor health
	for name, monitor := range o.lstMonitors {
		if monitor.IsHealthy() {
			o.metrics.LSTMonitorHealth.WithLabelValues(name).Set(1)
		} else {
			o.metrics.LSTMonitorHealth.WithLabelValues(name).Set(0)
			o.logger.Warn("LST monitor unhealthy", "lstToken", name)
		}
	}

	// Check pending tasks
	o.taskMutex.RLock()
	pendingCount := len(o.pendingTasks)
	responseCount := len(o.taskResponses)
	o.taskMutex.RUnlock()

	o.metrics.PendingTasks.Set(float64(pendingCount))
	o.metrics.ProcessedTasks.Set(float64(responseCount))

	// Clean up old responses
	o.cleanupOldResponses()

	o.logger.Debug("Health check completed",
		"pendingTasks", pendingCount,
		"processedResponses", responseCount)
}

// cleanupOldResponses cleans up old task responses
func (o *EnhancedOperator) cleanupOldResponses() {
	cutoff := time.Now().Add(-24 * time.Hour)

	o.taskMutex.Lock()
	defer o.taskMutex.Unlock()

	for taskIndex, responseData := range o.taskResponses {
		if responseData.ProcessedAt.Before(cutoff) {
			delete(o.taskResponses, taskIndex)
		}
	}

	for taskIndex, taskInfo := range o.pendingTasks {
		if taskInfo.ReceivedAt.Before(cutoff) {
			delete(o.pendingTasks, taskIndex)
		}
	}
}

// Helper methods

// createTaskResponseHash creates a hash of task response for signing
func (o *EnhancedOperator) createTaskResponseHash(response *types.TaskResponse) [32]byte {
	data := fmt.Sprintf("%d:%d:%d:%s",
		response.ReferenceTaskIndex,
		response.YieldRate,
		response.Timestamp.Unix(),
		response.DataHash,
	)
	hash := sha3.NewLegacyKeccak256()
	hash.Write([]byte(data))
	var result [32]byte
	copy(result[:], hash.Sum(nil))
	return result
}

// createResponseDataHash creates a hash for response data
func (o *EnhancedOperator) createResponseDataHash(lstToken string, yieldRate uint32) string {
	data := fmt.Sprintf("%s:%d:%d", lstToken, yieldRate, time.Now().Unix())
	hash := sha3.NewLegacyKeccak256()
	hash.Write([]byte(data))
	return fmt.Sprintf("0x%x", hash.Sum(nil))
}

// startHttpServer starts the HTTP server for health checks and metrics
func (o *EnhancedOperator) startHttpServer() {
	router := mux.NewRouter()

	// Health check endpoint
	router.HandleFunc("/health", o.healthHandler).Methods("GET")
	
	// Status endpoint
	router.HandleFunc("/status", o.statusHandler).Methods("GET")
	
	// Metrics endpoint
	router.Handle("/metrics", promhttp.HandlerFor(o.metricsRegistry, promhttp.HandlerOpts{}))

	o.httpServer = &http.Server{
		Addr:    o.config.Operator.ServerIpPortAddr,
		Handler: router,
	}

	o.logger.Info("Starting operator HTTP server", "addr", o.config.Operator.ServerIpPortAddr)
	if err := o.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		o.logger.Error("HTTP server error", "error", err)
	}
}

// startMetricsServer starts the metrics server
func (o *EnhancedOperator) startMetricsServer() {
	if o.config.Operator.EnableMetrics {
		metricsRouter := mux.NewRouter()
		metricsRouter.Handle("/metrics", promhttp.HandlerFor(o.metricsRegistry, promhttp.HandlerOpts{}))

		metricsServer := &http.Server{
			Addr:    o.config.Operator.MetricsIpPortAddr,
			Handler: metricsRouter,
		}

		o.logger.Info("Starting operator metrics server", "addr", o.config.Operator.MetricsIpPortAddr)
		if err := metricsServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			o.logger.Error("Metrics server error", "error", err)
		}
	}
}

// HTTP handlers

func (o *EnhancedOperator) healthHandler(w http.ResponseWriter, r *http.Request) {
	status := "healthy"
	
	// Check LST monitors
	for name, monitor := range o.lstMonitors {
		if !monitor.IsHealthy() {
			status = "degraded"
			break
		}
	}

	response := map[string]interface{}{
		"status":     status,
		"timestamp":  time.Now(),
		"operatorId": o.operatorId.Hex(),
		"version":    SEM_VER,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (o *EnhancedOperator) statusHandler(w http.ResponseWriter, r *http.Request) {
	o.taskMutex.RLock()
	pendingCount := len(o.pendingTasks)
	responseCount := len(o.taskResponses)
	o.taskMutex.RUnlock()

	response := map[string]interface{}{
		"operatorId":       o.operatorId.Hex(),
		"operatorAddress":  o.operatorAddr.Hex(),
		"pendingTasks":     pendingCount,
		"processedTasks":   responseCount,
		"lstMonitors":      o.getLSTMonitorStatus(),
		"version":          SEM_VER,
		"uptime":           time.Since(time.Now()).String(), // This would be actual uptime
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// getLSTMonitorStatus gets status of all LST monitors
func (o *EnhancedOperator) getLSTMonitorStatus() map[string]interface{} {
	status := make(map[string]interface{})
	
	for name, monitor := range o.lstMonitors {
		status[name] = map[string]interface{}{
			"healthy":     monitor.IsHealthy(),
			"lastUpdate":  monitor.GetLastUpdateTime(),
		}
	}
	
	return status
}

// Public query methods

// GetOperatorInfo returns operator information
func (o *EnhancedOperator) GetOperatorInfo() *types.OperatorInfo {
	return &types.OperatorInfo{
		OperatorId:      o.operatorId,
		OperatorAddress: o.operatorAddr.Hex(),
		BlsKeypair:      o.blsKeypair,
	}
}

// GetTaskStats returns task statistics
func (o *EnhancedOperator) GetTaskStats() *types.TaskStats {
	o.taskMutex.RLock()
	defer o.taskMutex.RUnlock()

	return &types.TaskStats{
		PendingTasks:    len(o.pendingTasks),
		ProcessedTasks:  len(o.taskResponses),
	}
}