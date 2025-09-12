package core

import (
	"context"
	"fmt"
	"time"

	"github.com/YieldSync/yieldsync-operator/chainio"
	"github.com/YieldSync/yieldsync-operator/metrics"
	"github.com/YieldSync/yieldsync-operator/types"
	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	sdklogging "github.com/Layr-Labs/eigensdk-go/logging"
)

// TaskMonitor monitors for new tasks and responds to them
type TaskMonitor struct {
	yieldSyncContracts *chainio.YieldSyncContracts
	lstMonitors        map[string]*LSTMonitor
	blsKeypair         *bls.KeyPair
	rpcClient          *chainio.RPCClient
	logger             sdklogging.Logger
	metrics            *metrics.OperatorMetrics
	
	// Task tracking
	lastProcessedTask uint32
}

// NewTaskMonitor creates a new task monitor
func NewTaskMonitor(
	yieldSyncContracts *chainio.YieldSyncContracts,
	lstMonitors map[string]*LSTMonitor,
	blsKeypair *bls.KeyPair,
	rpcClient *chainio.RPCClient,
	logger sdklogging.Logger,
	metrics *metrics.OperatorMetrics,
) *TaskMonitor {
	return &TaskMonitor{
		yieldSyncContracts: yieldSyncContracts,
		lstMonitors:        lstMonitors,
		blsKeypair:         blsKeypair,
		rpcClient:          rpcClient,
		logger:             logger,
		metrics:            metrics,
		lastProcessedTask:  0,
	}
}

// Start starts the task monitor
func (tm *TaskMonitor) Start(ctx context.Context) error {
	tm.logger.Info("Starting task monitor")
	
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			tm.logger.Info("Task monitor stopped")
			return ctx.Err()
		case <-ticker.C:
			if err := tm.checkForNewTasks(); err != nil {
				tm.logger.Error("Error checking for new tasks", "error", err)
				tm.metrics.IncrementTaskMonitorErrors()
			}
		}
	}
}

// checkForNewTasks checks for new tasks and processes them
func (tm *TaskMonitor) checkForNewTasks() error {
	// Get the latest task number
	latestTaskNum, err := tm.yieldSyncContracts.TaskManager.LatestTaskNum(nil)
	if err != nil {
		return fmt.Errorf("failed to get latest task number: %w", err)
	}
	
	// Check if there are new tasks
	if latestTaskNum <= tm.lastProcessedTask {
		return nil
	}
	
	tm.logger.Info("New tasks detected", "latestTaskNum", latestTaskNum, "lastProcessedTask", tm.lastProcessedTask)
	
	// Process new tasks
	for taskNum := tm.lastProcessedTask + 1; taskNum <= latestTaskNum; taskNum++ {
		if err := tm.processTask(taskNum); err != nil {
			tm.logger.Error("Error processing task", "taskNum", taskNum, "error", err)
			tm.metrics.IncrementTaskProcessingErrors()
			continue
		}
		tm.metrics.IncrementTasksProcessed()
	}
	
	tm.lastProcessedTask = latestTaskNum
	return nil
}

// processTask processes a single task
func (tm *TaskMonitor) processTask(taskNum uint32) error {
	tm.logger.Info("Processing task", "taskNum", taskNum)
	
	// Get task details
	task, err := tm.getTaskDetails(taskNum)
	if err != nil {
		return fmt.Errorf("failed to get task details: %w", err)
	}
	
	// Get yield data for the LST
	lstMonitor, exists := tm.lstMonitors[task.LSTToken]
	if !exists {
		return fmt.Errorf("no monitor found for LST token: %s", task.LSTToken)
	}
	
	yieldData, err := lstMonitor.GetLatestYieldData()
	if err != nil {
		return fmt.Errorf("failed to get yield data: %w", err)
	}
	
	// Create task response
	taskResponse := &types.TaskResponse{
		ReferenceTaskIndex: taskNum,
		YieldRate:          yieldData.YieldRate,
		Timestamp:          time.Now(),
		DataHash:           yieldData.DataHash,
		LSTData:            []types.LSTYieldData{*yieldData},
	}
	
	// Sign the task response
	signature, err := tm.signTaskResponse(taskResponse)
	if err != nil {
		return fmt.Errorf("failed to sign task response: %w", err)
	}
	
	// Send response to aggregator
	if err := tm.rpcClient.SendTaskResponse(taskResponse, signature); err != nil {
		return fmt.Errorf("failed to send task response: %w", err)
	}
	
	tm.logger.Info("Task processed successfully", "taskNum", taskNum)
	return nil
}

// getTaskDetails gets the details of a task
func (tm *TaskMonitor) getTaskDetails(taskNum uint32) (*types.Task, error) {
	// Get task hash
	taskHash, err := tm.yieldSyncContracts.TaskManager.AllTaskHashes(nil, taskNum)
	if err != nil {
		return nil, fmt.Errorf("failed to get task hash: %w", err)
	}
	
	// For now, return a mock task
	// In production, you would decode the task hash or store task details
	return &types.Task{
		LSTToken:                "stETH", // This would come from the actual task data
		TaskCreatedBlock:        uint32(time.Now().Unix()),
		QuorumNumbers:           []byte{0}, // This would come from the actual task data
		QuorumThresholdPercentage: 50,     // This would come from the actual task data
	}, nil
}

// signTaskResponse signs a task response
func (tm *TaskMonitor) signTaskResponse(taskResponse *types.TaskResponse) ([]byte, error) {
	// Create message hash
	messageHash := tm.createMessageHash(taskResponse)
	
	// Sign with BLS keypair
	signature := tm.blsKeypair.SignMessage(messageHash)
	
	return signature, nil
}

// createMessageHash creates a hash of the task response for signing
func (tm *TaskMonitor) createMessageHash(taskResponse *types.TaskResponse) []byte {
	// This should match the hash function used in the smart contract
	// For now, create a simple hash
	data := fmt.Sprintf("%d:%d:%d:%s", 
		taskResponse.ReferenceTaskIndex,
		taskResponse.YieldRate,
		taskResponse.Timestamp.Unix(),
		taskResponse.DataHash,
	)
	return []byte(data)
}
