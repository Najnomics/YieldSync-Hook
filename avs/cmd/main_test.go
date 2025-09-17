package main

import (
	"encoding/json"
	"testing"

	performerV1 "github.com/Layr-Labs/protocol-apis/gen/protos/eigenlayer/hourglass/v1/performer"
	"go.uber.org/zap"
)

func Test_LVRAuctionTaskRequestPayload(t *testing.T) {
	// ------------------------------------------------------------------------
	// LVR Auction Task Tests
	// ------------------------------------------------------------------------

	logger, err := zap.NewDevelopment()
	if err != nil {
		t.Errorf("Failed to create logger: %v", err)
	}

	performer := NewLVRAuctionPerformer(logger)

	// Test basic task validation
	taskRequest := &performerV1.TaskRequest{
		TaskId:  []byte("test-lvr-task-id"),
		Payload: []byte("test-data"),
	}

	err = performer.ValidateTask(taskRequest)
	if err != nil {
		t.Errorf("ValidateTask failed: %v", err)
	}

	resp, err := performer.HandleTask(taskRequest)
	if err != nil {
		t.Errorf("HandleTask failed: %v", err)
	}

	t.Logf("Response: %v", resp)
}

func Test_LVRAuctionTaskTypes(t *testing.T) {
	logger, err := zap.NewDevelopment()
	if err != nil {
		t.Errorf("Failed to create logger: %v", err)
	}

	performer := NewLVRAuctionPerformer(logger)

	testCases := []struct {
		name     string
		taskType TaskType
		params   map[string]interface{}
	}{
		{
			name:     "LVR Monitoring Task",
			taskType: TaskTypeLVRMonitoring,
			params: map[string]interface{}{
				"pool_address": "0x1234567890abcdef",
				"threshold":    1000,
			},
		},
		{
			name:     "Auction Creation Task",
			taskType: TaskTypeAuctionCreation,
			params: map[string]interface{}{
				"pool_id":     "0xabcdef",
				"duration":    3600,
				"min_bid":     100,
			},
		},
		{
			name:     "Bid Validation Task",
			taskType: TaskTypeBidValidation,
			params: map[string]interface{}{
				"auction_id": "0x123",
				"bid_amount": 500,
				"bidder":     "0xbidder",
			},
		},
		{
			name:     "Settlement Task",
			taskType: TaskTypeSettlement,
			params: map[string]interface{}{
				"auction_id": "0x123",
				"winner":     "0xwinner",
				"amount":     1000,
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Create task payload
			payload := TaskPayload{
				Type:       tc.taskType,
				Parameters: tc.params,
			}

			payloadBytes, err := json.Marshal(payload)
			if err != nil {
				t.Errorf("Failed to marshal payload: %v", err)
				return
			}

			taskRequest := &performerV1.TaskRequest{
				TaskId:  []byte("test-task-" + string(tc.taskType)),
				Payload: payloadBytes,
			}

			// Test validation
			err = performer.ValidateTask(taskRequest)
			if err != nil {
				t.Errorf("ValidateTask failed for %s: %v", tc.name, err)
				return
			}

			// Test handling
			resp, err := performer.HandleTask(taskRequest)
			if err != nil {
				t.Errorf("HandleTask failed for %s: %v", tc.name, err)
				return
			}

			if resp == nil {
				t.Errorf("HandleTask returned nil response for %s", tc.name)
				return
			}

			if len(resp.Result) == 0 {
				t.Errorf("HandleTask returned empty result for %s", tc.name)
				return
			}

			t.Logf("%s completed successfully with result: %s", tc.name, string(resp.Result))
		})
	}
}

func Test_TaskPayloadParsing(t *testing.T) {
	// Test payload parsing functionality
	testPayload := TaskPayload{
		Type: TaskTypeLVRMonitoring,
		Parameters: map[string]interface{}{
			"pool_address": "0x1234567890abcdef",
			"threshold":    1000,
		},
	}

	payloadBytes, err := json.Marshal(testPayload)
	if err != nil {
		t.Errorf("Failed to marshal test payload: %v", err)
		return
	}

	taskRequest := &performerV1.TaskRequest{
		TaskId:  []byte("parse-test"),
		Payload: payloadBytes,
	}

	parsedPayload, err := parseTaskPayload(taskRequest)
	if err != nil {
		t.Errorf("Failed to parse task payload: %v", err)
		return
	}

	if parsedPayload.Type != TaskTypeLVRMonitoring {
		t.Errorf("Expected task type %s, got %s", TaskTypeLVRMonitoring, parsedPayload.Type)
	}

	if parsedPayload.Parameters["threshold"] != float64(1000) {
		t.Errorf("Expected threshold 1000, got %v", parsedPayload.Parameters["threshold"])
	}

	t.Logf("Payload parsing test successful: %+v", parsedPayload)
}