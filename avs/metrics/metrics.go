package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// OperatorMetrics contains all metrics for the operator
type OperatorMetrics struct {
	Registry *prometheus.Registry

	// Task metrics
	TasksReceived           prometheus.Counter
	TasksProcessed          prometheus.Counter
	ResponsesSubmitted      prometheus.Counter
	ResponsesFailedSubmission prometheus.Counter
	PendingTasks            prometheus.Gauge
	ProcessedTasks          prometheus.Gauge

	// LST monitoring metrics
	LSTMonitorHealth        *prometheus.GaugeVec
	YieldDataFetches        *prometheus.CounterVec
	YieldDataErrors         *prometheus.CounterVec
	LastYieldRate           *prometheus.GaugeVec

	// Performance metrics
	TaskProcessingDuration  prometheus.Histogram
	ResponseSigningDuration prometheus.Histogram
	NetworkLatency          prometheus.Histogram

	// Error metrics
	ErrorCount              *prometheus.CounterVec
	CriticalErrors          prometheus.Counter
}

// NewOperatorMetrics creates new operator metrics
func NewOperatorMetrics(registry *prometheus.Registry) *OperatorMetrics {
	factory := promauto.With(registry)

	return &OperatorMetrics{
		Registry: registry,

		TasksReceived: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_operator_tasks_received_total",
			Help: "Total number of tasks received by the operator",
		}),

		TasksProcessed: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_operator_tasks_processed_total",
			Help: "Total number of tasks processed by the operator",
		}),

		ResponsesSubmitted: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_operator_responses_submitted_total",
			Help: "Total number of responses submitted to aggregator",
		}),

		ResponsesFailedSubmission: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_operator_responses_failed_total",
			Help: "Total number of responses that failed to submit",
		}),

		PendingTasks: factory.NewGauge(prometheus.GaugeOpts{
			Name: "yieldsync_operator_pending_tasks",
			Help: "Number of tasks currently pending processing",
		}),

		ProcessedTasks: factory.NewGauge(prometheus.GaugeOpts{
			Name: "yieldsync_operator_processed_tasks",
			Help: "Number of tasks that have been processed",
		}),

		LSTMonitorHealth: factory.NewGaugeVec(prometheus.GaugeOpts{
			Name: "yieldsync_operator_lst_monitor_healthy",
			Help: "Health status of LST monitors (1=healthy, 0=unhealthy)",
		}, []string{"lst_token"}),

		YieldDataFetches: factory.NewCounterVec(prometheus.CounterOpts{
			Name: "yieldsync_operator_yield_data_fetches_total",
			Help: "Total number of yield data fetches by LST token",
		}, []string{"lst_token", "status"}),

		YieldDataErrors: factory.NewCounterVec(prometheus.CounterOpts{
			Name: "yieldsync_operator_yield_data_errors_total",
			Help: "Total number of yield data fetch errors by LST token",
		}, []string{"lst_token", "error_type"}),

		LastYieldRate: factory.NewGaugeVec(prometheus.GaugeOpts{
			Name: "yieldsync_operator_last_yield_rate",
			Help: "Last observed yield rate by LST token in basis points",
		}, []string{"lst_token"}),

		TaskProcessingDuration: factory.NewHistogram(prometheus.HistogramOpts{
			Name: "yieldsync_operator_task_processing_duration_seconds",
			Help: "Time taken to process a task",
			Buckets: prometheus.DefBuckets,
		}),

		ResponseSigningDuration: factory.NewHistogram(prometheus.HistogramOpts{
			Name: "yieldsync_operator_response_signing_duration_seconds",
			Help: "Time taken to sign a response",
			Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0},
		}),

		NetworkLatency: factory.NewHistogram(prometheus.HistogramOpts{
			Name: "yieldsync_operator_network_latency_seconds",
			Help: "Network latency for external calls",
			Buckets: []float64{0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0},
		}),

		ErrorCount: factory.NewCounterVec(prometheus.CounterOpts{
			Name: "yieldsync_operator_errors_total",
			Help: "Total number of errors by type",
		}, []string{"error_type", "component"}),

		CriticalErrors: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_operator_critical_errors_total",
			Help: "Total number of critical errors",
		}),
	}
}

// AggregatorMetrics contains all metrics for the aggregator
type AggregatorMetrics struct {
	Registry *prometheus.Registry

	// Task metrics
	TasksCreated          prometheus.Counter
	TasksExpired          prometheus.Counter
	ActiveTasks           prometheus.Gauge

	// Response metrics
	ResponsesReceived     prometheus.Counter
	ResponsesAggregated   prometheus.Counter
	ResponsesRejected     prometheus.Counter

	// BLS aggregation metrics
	SignatureAggregations prometheus.Counter
	AggregationDuration   prometheus.Histogram
	QuorumReached         prometheus.Counter

	// Operator metrics
	ActiveOperators       prometheus.Gauge
	OperatorResponseTime  *prometheus.HistogramVec

	// Network metrics
	HTTPRequests          *prometheus.CounterVec
	HTTPDuration          *prometheus.HistogramVec
}

// NewAggregatorMetrics creates new aggregator metrics
func NewAggregatorMetrics(registry *prometheus.Registry) *AggregatorMetrics {
	factory := promauto.With(registry)

	return &AggregatorMetrics{
		Registry: registry,

		TasksCreated: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_aggregator_tasks_created_total",
			Help: "Total number of tasks created by the aggregator",
		}),

		TasksExpired: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_aggregator_tasks_expired_total",
			Help: "Total number of tasks that expired without completion",
		}),

		ActiveTasks: factory.NewGauge(prometheus.GaugeOpts{
			Name: "yieldsync_aggregator_active_tasks",
			Help: "Number of currently active tasks awaiting responses",
		}),

		ResponsesReceived: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_aggregator_responses_received_total",
			Help: "Total number of responses received from operators",
		}),

		ResponsesAggregated: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_aggregator_responses_aggregated_total",
			Help: "Total number of responses that were aggregated and submitted",
		}),

		ResponsesRejected: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_aggregator_responses_rejected_total",
			Help: "Total number of responses that were rejected",
		}),

		SignatureAggregations: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_aggregator_signature_aggregations_total",
			Help: "Total number of BLS signature aggregations performed",
		}),

		AggregationDuration: factory.NewHistogram(prometheus.HistogramOpts{
			Name: "yieldsync_aggregator_aggregation_duration_seconds",
			Help: "Time taken to aggregate signatures",
			Buckets: []float64{0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0},
		}),

		QuorumReached: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_aggregator_quorum_reached_total",
			Help: "Total number of times quorum was reached for tasks",
		}),

		ActiveOperators: factory.NewGauge(prometheus.GaugeOpts{
			Name: "yieldsync_aggregator_active_operators",
			Help: "Number of currently active operators",
		}),

		OperatorResponseTime: factory.NewHistogramVec(prometheus.HistogramOpts{
			Name: "yieldsync_aggregator_operator_response_time_seconds",
			Help: "Time taken by operators to respond to tasks",
			Buckets: []float64{1.0, 5.0, 10.0, 30.0, 60.0, 300.0, 600.0},
		}, []string{"operator_id"}),

		HTTPRequests: factory.NewCounterVec(prometheus.CounterOpts{
			Name: "yieldsync_aggregator_http_requests_total",
			Help: "Total number of HTTP requests by endpoint and status",
		}, []string{"endpoint", "method", "status"}),

		HTTPDuration: factory.NewHistogramVec(prometheus.HistogramOpts{
			Name: "yieldsync_aggregator_http_duration_seconds",
			Help: "HTTP request duration by endpoint",
			Buckets: prometheus.DefBuckets,
		}, []string{"endpoint", "method"}),
	}
}

// ChallengerMetrics contains all metrics for the challenger
type ChallengerMetrics struct {
	Registry *prometheus.Registry

	// Response verification metrics
	ResponsesVerified     prometheus.Counter
	ResponsesInvalid      prometheus.Counter
	VerificationDuration  prometheus.Histogram

	// Challenge metrics
	ChallengesInitiated   prometheus.Counter
	ChallengesSubmitted   prometheus.Counter
	ChallengesSuccessful  prometheus.Counter
	ChallengesFailed      prometheus.Counter
	ActiveChallenges      prometheus.Gauge

	// LST verification metrics
	YieldVerifications    *prometheus.CounterVec
	YieldDiscrepancies    *prometheus.HistogramVec

	// Reward metrics
	ChallengeRewards      prometheus.Counter
	TotalRewardsEarned    prometheus.Gauge
}

// NewChallengerMetrics creates new challenger metrics
func NewChallengerMetrics(registry *prometheus.Registry) *ChallengerMetrics {
	factory := promauto.With(registry)

	return &ChallengerMetrics{
		Registry: registry,

		ResponsesVerified: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_challenger_responses_verified_total",
			Help: "Total number of responses verified by the challenger",
		}),

		ResponsesInvalid: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_challenger_responses_invalid_total",
			Help: "Total number of invalid responses detected",
		}),

		VerificationDuration: factory.NewHistogram(prometheus.HistogramOpts{
			Name: "yieldsync_challenger_verification_duration_seconds",
			Help: "Time taken to verify a response",
			Buckets: []float64{0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0},
		}),

		ChallengesInitiated: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_challenger_challenges_initiated_total",
			Help: "Total number of challenges initiated",
		}),

		ChallengesSubmitted: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_challenger_challenges_submitted_total",
			Help: "Total number of challenges submitted to contract",
		}),

		ChallengesSuccessful: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_challenger_challenges_successful_total",
			Help: "Total number of successful challenges",
		}),

		ChallengesFailed: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_challenger_challenges_failed_total",
			Help: "Total number of failed challenges",
		}),

		ActiveChallenges: factory.NewGauge(prometheus.GaugeOpts{
			Name: "yieldsync_challenger_active_challenges",
			Help: "Number of currently active challenges",
		}),

		YieldVerifications: factory.NewCounterVec(prometheus.CounterOpts{
			Name: "yieldsync_challenger_yield_verifications_total",
			Help: "Total number of yield verifications by LST token and result",
		}, []string{"lst_token", "result"}),

		YieldDiscrepancies: factory.NewHistogramVec(prometheus.HistogramOpts{
			Name: "yieldsync_challenger_yield_discrepancies_bps",
			Help: "Yield rate discrepancies in basis points",
			Buckets: []float64{1, 5, 10, 25, 50, 100, 250, 500, 1000},
		}, []string{"lst_token"}),

		ChallengeRewards: factory.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_challenger_rewards_total",
			Help: "Total number of challenge rewards received",
		}),

		TotalRewardsEarned: factory.NewGauge(prometheus.GaugeOpts{
			Name: "yieldsync_challenger_total_rewards_earned_eth",
			Help: "Total rewards earned in ETH",
		}),
	}
}