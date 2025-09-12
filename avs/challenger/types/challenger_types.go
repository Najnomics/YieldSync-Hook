package types

import (
	"math/big"
	"time"
)

// ChallengeStatus represents the status of a challenge
type ChallengeStatus int

const (
	ChallengePending ChallengeStatus = iota
	ChallengeSubmitted
	ChallengeSuccessful
	ChallengeFailed
)

func (s ChallengeStatus) String() string {
	switch s {
	case ChallengePending:
		return "pending"
	case ChallengeSubmitted:
		return "submitted"
	case ChallengeSuccessful:
		return "successful"
	case ChallengeFailed:
		return "failed"
	default:
		return "unknown"
	}
}

// ChallengeInfo represents information about an active challenge
type ChallengeInfo struct {
	TaskIndex       uint32          `json:"task_index"`
	ChallengeId     uint64          `json:"challenge_id,omitempty"`
	ChallengedAt    time.Time       `json:"challenged_at"`
	ResolvedAt      time.Time       `json:"resolved_at,omitempty"`
	ReportedRate    uint32          `json:"reported_rate"`
	ActualRate      uint32          `json:"actual_rate"`
	Evidence        []byte          `json:"evidence"`
	Status          ChallengeStatus `json:"status"`
	SubmittedBlock  uint32          `json:"submitted_block,omitempty"`
	Reward          *big.Int        `json:"reward,omitempty"`
}

// ChallengeResult represents the result of a completed challenge
type ChallengeResult struct {
	TaskIndex     uint32        `json:"task_index"`
	ChallengeInfo ChallengeInfo `json:"challenge_info"`
	Success       bool          `json:"success"`
}

// ChallengeStats represents statistics about challenges
type ChallengeStats struct {
	ActiveChallenges     int `json:"active_challenges"`
	TotalChallenges      int `json:"total_challenges"`
	SuccessfulChallenges int `json:"successful_challenges"`
	FailedChallenges     int `json:"failed_challenges"`
}

// YieldVerificationResult represents the result of yield verification
type YieldVerificationResult struct {
	TaskIndex    uint32    `json:"task_index"`
	LSTToken     string    `json:"lst_token"`
	ReportedRate uint32    `json:"reported_rate"`
	ActualRate   uint32    `json:"actual_rate"`
	IsValid      bool      `json:"is_valid"`
	Tolerance    uint32    `json:"tolerance"`
	Timestamp    time.Time `json:"timestamp"`
}

// ChallengeEvidence represents evidence for a challenge
type ChallengeEvidence struct {
	LSTToken      string      `json:"lst_token"`
	ActualRate    uint32      `json:"actual_rate"`
	Timestamp     int64       `json:"timestamp"`
	EvidenceType  string      `json:"evidence_type"`
	ProtocolData  interface{} `json:"protocol_data"`
	Signatures    []string    `json:"signatures,omitempty"`
	ProofData     []byte      `json:"proof_data,omitempty"`
}

// ChallengeRequest represents a request to initiate a challenge
type ChallengeRequest struct {
	TaskIndex    uint32 `json:"task_index"`
	ReportedRate uint32 `json:"reported_rate"`
	ActualRate   uint32 `json:"actual_rate"`
	Evidence     []byte `json:"evidence"`
}

// ChallengeResponse represents the response to a challenge request
type ChallengeResponse struct {
	ChallengeId uint64 `json:"challenge_id"`
	Success     bool   `json:"success"`
	Message     string `json:"message"`
}