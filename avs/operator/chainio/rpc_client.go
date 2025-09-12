package chainio

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/YieldSync/yieldsync-operator/types"
	sdklogging "github.com/Layr-Labs/eigensdk-go/logging"
)

// RPCClient handles RPC communication with the aggregator
type RPCClient struct {
	serverURL string
	httpClient *http.Client
	logger    sdklogging.Logger
}

// NewRPCClient creates a new RPC client
func NewRPCClient(serverURL string, logger sdklogging.Logger) *RPCClient {
	return &RPCClient{
		serverURL: serverURL,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		logger: logger,
	}
}

// SendTaskResponse sends a task response to the aggregator
func (rc *RPCClient) SendTaskResponse(taskResponse *types.TaskResponse, signature []byte) error {
	// Create request payload
	payload := map[string]interface{}{
		"task_response": taskResponse,
		"signature":     signature,
		"timestamp":     time.Now().Unix(),
	}
	
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal task response: %w", err)
	}
	
	// Send HTTP request
	req, err := http.NewRequest("POST", rc.serverURL+"/task-response", bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}
	
	req.Header.Set("Content-Type", "application/json")
	
	resp, err := rc.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("aggregator returned error status: %d", resp.StatusCode)
	}
	
	rc.logger.Info("Task response sent successfully", 
		"taskIndex", taskResponse.ReferenceTaskIndex,
		"yieldRate", taskResponse.YieldRate,
	)
	
	return nil
}

// GetLatestTasks gets the latest tasks from the aggregator
func (rc *RPCClient) GetLatestTasks() ([]types.Task, error) {
	req, err := http.NewRequest("GET", rc.serverURL+"/tasks", nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	
	resp, err := rc.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("aggregator returned error status: %d", resp.StatusCode)
	}
	
	var tasks []types.Task
	if err := json.NewDecoder(resp.Body).Decode(&tasks); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}
	
	return tasks, nil
}

// HealthCheck checks if the aggregator is healthy
func (rc *RPCClient) HealthCheck() error {
	req, err := http.NewRequest("GET", rc.serverURL+"/health", nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}
	
	resp, err := rc.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("aggregator health check failed: %d", resp.StatusCode)
	}
	
	return nil
}
