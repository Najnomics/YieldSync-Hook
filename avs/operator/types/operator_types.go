package types

import (
	"time"
	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	sdktypes "github.com/Layr-Labs/eigensdk-go/types"
)

// OperatorInfo represents operator information
type OperatorInfo struct {
	OperatorAddress string             `json:"operator_address"`
	OperatorId      sdktypes.OperatorId `json:"operator_id"`
	BlsKeypair      *bls.KeyPair       `json:"-"` // Don't serialize private key
}

// TaskInfo represents information about a task received by the operator
type TaskInfo struct {
	TaskIndex        uint32                          `json:"task_index"`
	LSTToken         string                          `json:"lst_token"`
	TaskCreatedBlock uint32                          `json:"task_created_block"`
	QuorumNumbers    sdktypes.QuorumNums            `json:"quorum_numbers"`
	ReceivedAt       time.Time                       `json:"received_at"`
	DeadlineAt       time.Time                       `json:"deadline_at"`
}

// TaskResponse represents a task response to be submitted
type TaskResponse struct {
	ReferenceTaskIndex uint32    `json:"reference_task_index"`
	YieldRate          uint32    `json:"yield_rate"`
	Timestamp          time.Time `json:"timestamp"`
	DataHash           string    `json:"data_hash"`
}

// SignedTaskResponse represents a signed task response
type SignedTaskResponse struct {
	TaskResponse *TaskResponse  `json:"task_response"`
	BlsSignature *bls.Signature `json:"bls_signature"`
	OperatorId   sdktypes.OperatorId `json:"operator_id"`
}

// SubmissionStatus represents the status of a task response submission
type SubmissionStatus int

const (
	StatusPending SubmissionStatus = iota
	StatusSubmitted
	StatusFailed
	StatusConfirmed
)

func (s SubmissionStatus) String() string {
	switch s {
	case StatusPending:
		return "pending"
	case StatusSubmitted:
		return "submitted"
	case StatusFailed:
		return "failed"
	case StatusConfirmed:
		return "confirmed"
	default:
		return "unknown"
	}
}

// TaskResponseData represents complete data about a task response
type TaskResponseData struct {
	TaskInfo         *TaskInfo         `json:"task_info"`
	SignedResponse   *SignedTaskResponse `json:"signed_response"`
	ProcessedAt      time.Time         `json:"processed_at"`
	SubmissionStatus SubmissionStatus  `json:"submission_status"`
	Error            string            `json:"error,omitempty"`
	RetryCount       int               `json:"retry_count"`
}

// TaskStats represents statistics about task processing
type TaskStats struct {
	PendingTasks    int `json:"pending_tasks"`
	ProcessedTasks  int `json:"processed_tasks"`
	FailedTasks     int `json:"failed_tasks"`
	SuccessRate     float64 `json:"success_rate"`
}

// OperatorHealthStatus represents the health status of the operator
type OperatorHealthStatus struct {
	Status           string            `json:"status"`
	OperatorId       string            `json:"operator_id"`
	LastTaskReceived time.Time         `json:"last_task_received"`
	LSTMonitorStatus map[string]bool   `json:"lst_monitor_status"`
	TaskStats        TaskStats         `json:"task_stats"`
	Uptime           time.Duration     `json:"uptime"`
}

// YieldDataRequest represents a request for yield data
type YieldDataRequest struct {
	LSTToken  string    `json:"lst_token"`
	Timestamp time.Time `json:"timestamp,omitempty"`
}

// YieldDataResponse represents a response with yield data
type YieldDataResponse struct {
	LSTToken    string    `json:"lst_token"`
	YieldRate   uint32    `json:"yield_rate"`
	Timestamp   time.Time `json:"timestamp"`
	Source      string    `json:"source"`
	Success     bool      `json:"success"`
	Error       string    `json:"error,omitempty"`
}