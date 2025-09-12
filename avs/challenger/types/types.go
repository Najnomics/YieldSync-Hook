the package types

import "time"

// Challenge represents a challenge to a task response
type Challenge struct {
	TaskIndex           uint32    `json:"task_index"`
	TaskResponseHash    string    `json:"task_response_hash"`
	ChallengeReason     string    `json:"challenge_reason"`
	SubmittedAt         time.Time `json:"submitted_at"`
	Status              string    `json:"status"`
	TxHash              string    `json:"tx_hash"`
}

// ChallengeStatus represents the status of a challenge
type ChallengeStatus string

const (
	ChallengeStatusPending   ChallengeStatus = "pending"
	ChallengeStatusAccepted  ChallengeStatus = "accepted"
	ChallengeStatusRejected  ChallengeStatus = "rejected"
	ChallengeStatusResolved  ChallengeStatus = "resolved"
)

// VerificationResult represents the result of verifying a task response
type VerificationResult struct {
	IsValid           bool    `json:"is_valid"`
	ActualYieldRate   uint32  `json:"actual_yield_rate"`
	ReportedYieldRate uint32  `json:"reported_yield_rate"`
	Error             string  `json:"error,omitempty"`
	Confidence        float64 `json:"confidence"`
}

// ChallengeMetrics represents metrics for the challenger
type ChallengeMetrics struct {
	TotalChallenges     uint32    `json:"total_challenges"`
	SuccessfulChallenges uint32    `json:"successful_challenges"`
	FailedChallenges    uint32    `json:"failed_challenges"`
	LastChallengeTime   time.Time `json:"last_challenge_time"`
	AverageResponseTime time.Duration `json:"average_response_time"`
}
