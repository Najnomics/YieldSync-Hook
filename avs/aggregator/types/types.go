package types

import (
	"time"
	"github.com/YieldSync/yieldsync-operator/types"
)

// TaskResponseWithSignature represents a task response with its signature
type TaskResponseWithSignature struct {
	TaskResponse    *types.TaskResponse `json:"task_response"`
	Signature       []byte              `json:"signature"`
	OperatorAddress string              `json:"operator_address"`
	Timestamp       time.Time           `json:"timestamp"`
}

// AggregatedSignature represents an aggregated BLS signature
type AggregatedSignature struct {
	NonSignerStakesAndSignature NonSignerStakesAndSignature `json:"non_signer_stakes_and_signature"`
}

// NonSignerStakesAndSignature represents the non-signer stakes and signature structure
type NonSignerStakesAndSignature struct {
	NonSignerQuorumBitmapIndices []uint32  `json:"non_signer_quorum_bitmap_indices"`
	NonSignerPubkeys            []G1Point  `json:"non_signer_pubkeys"`
	QuorumApks                  []G1Point  `json:"quorum_apks"`
	ApkG2                       G2Point    `json:"apk_g2"`
	Sigma                       []byte     `json:"sigma"`
	QuorumApkIndices            []uint32   `json:"quorum_apk_indices"`
	QuorumThresholdPercentages  []uint32   `json:"quorum_threshold_percentages"`
}

// G1Point represents a BN254 G1 point
type G1Point struct {
	X string `json:"x"`
	Y string `json:"y"`
}

// G2Point represents a BN254 G2 point
type G2Point struct {
	X [2]string `json:"x"`
	Y [2]string `json:"y"`
}

// OperatorResponse represents a response from an operator
type OperatorResponse struct {
	TaskIndex     uint32    `json:"task_index"`
	YieldRate     uint32    `json:"yield_rate"`
	Timestamp     time.Time `json:"timestamp"`
	DataHash      string    `json:"data_hash"`
	Signature     []byte    `json:"signature"`
	OperatorID    string    `json:"operator_id"`
	OperatorAddr  string    `json:"operator_addr"`
}

// TaskCreationRequest represents a request to create a new task
type TaskCreationRequest struct {
	LSTToken                string `json:"lst_token"`
	QuorumThresholdPercentage uint32 `json:"quorum_threshold_percentage"`
	QuorumNumbers           []byte `json:"quorum_numbers"`
}

// TaskCreationResponse represents the response to a task creation request
type TaskCreationResponse struct {
	TaskIndex uint32 `json:"task_index"`
	Success   bool   `json:"success"`
	Message   string `json:"message"`
}

// HealthCheckResponse represents a health check response
type HealthCheckResponse struct {
	Status    string    `json:"status"`
	Timestamp time.Time `json:"timestamp"`
	Uptime    string    `json:"uptime"`
	Version   string    `json:"version"`
}

// MetricsResponse represents a metrics response
type MetricsResponse struct {
	TasksCreated       uint32 `json:"tasks_created"`
	ResponsesProcessed uint32 `json:"responses_processed"`
	ActiveOperators    uint32 `json:"active_operators"`
	LastTaskTime       time.Time `json:"last_task_time"`
}
