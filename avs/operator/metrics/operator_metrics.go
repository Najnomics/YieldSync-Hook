package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// OperatorMetrics handles operator metrics
type OperatorMetrics struct {
	// Task metrics
	TasksProcessed      prometheus.Counter
	TaskProcessingErrors prometheus.Counter
	TaskMonitorErrors    prometheus.Counter
	
	// LST monitoring metrics
	LSTYieldUpdates     prometheus.CounterVec
	LSTYieldErrors      prometheus.CounterVec
	
	// RPC metrics
	RPCCallsTotal       prometheus.CounterVec
	RPCCallDuration     prometheus.HistogramVec
	
	// System metrics
	OperatorUptime      prometheus.Gauge
	LastTaskProcessed   prometheus.Gauge
	LastYieldUpdate     prometheus.GaugeVec
}

// NewOperatorMetrics creates a new OperatorMetrics instance
func NewOperatorMetrics(avsName, semVer string) *OperatorMetrics {
	return &OperatorMetrics{
		TasksProcessed: promauto.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_operator_tasks_processed_total",
			Help: "Total number of tasks processed",
		}),
		
		TaskProcessingErrors: promauto.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_operator_task_processing_errors_total",
			Help: "Total number of task processing errors",
		}),
		
		TaskMonitorErrors: promauto.NewCounter(prometheus.CounterOpts{
			Name: "yieldsync_operator_task_monitor_errors_total",
			Help: "Total number of task monitor errors",
		}),
		
		LSTYieldUpdates: *promauto.NewCounterVec(prometheus.CounterOpts{
			Name: "yieldsync_operator_lst_yield_updates_total",
			Help: "Total number of LST yield updates",
		}, []string{"lst_name"}),
		
		LSTYieldErrors: *promauto.NewCounterVec(prometheus.CounterOpts{
			Name: "yieldsync_operator_lst_yield_errors_total",
			Help: "Total number of LST yield errors",
		}, []string{"lst_name"}),
		
		RPCCallsTotal: *promauto.NewCounterVec(prometheus.CounterOpts{
			Name: "yieldsync_operator_rpc_calls_total",
			Help: "Total number of RPC calls",
		}, []string{"method", "status"}),
		
		RPCCallDuration: *promauto.NewHistogramVec(prometheus.HistogramOpts{
			Name: "yieldsync_operator_rpc_call_duration_seconds",
			Help: "Duration of RPC calls",
		}, []string{"method"}),
		
		OperatorUptime: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "yieldsync_operator_uptime_seconds",
			Help: "Operator uptime in seconds",
		}),
		
		LastTaskProcessed: promauto.NewGauge(prometheus.GaugeOpts{
			Name: "yieldsync_operator_last_task_processed",
			Help: "Last processed task number",
		}),
		
		LastYieldUpdate: *promauto.NewGaugeVec(prometheus.GaugeOpts{
			Name: "yieldsync_operator_last_yield_update_timestamp",
			Help: "Timestamp of last yield update",
		}, []string{"lst_name"}),
	}
}

// IncrementTasksProcessed increments the tasks processed counter
func (om *OperatorMetrics) IncrementTasksProcessed() {
	om.TasksProcessed.Inc()
}

// IncrementTaskProcessingErrors increments the task processing errors counter
func (om *OperatorMetrics) IncrementTaskProcessingErrors() {
	om.TaskProcessingErrors.Inc()
}

// IncrementTaskMonitorErrors increments the task monitor errors counter
func (om *OperatorMetrics) IncrementTaskMonitorErrors() {
	om.TaskMonitorErrors.Inc()
}

// IncrementLSTYieldUpdates increments the LST yield updates counter
func (om *OperatorMetrics) IncrementLSTYieldUpdates(lstName string) {
	om.LSTYieldUpdates.WithLabelValues(lstName).Inc()
}

// IncrementLSTYieldErrors increments the LST yield errors counter
func (om *OperatorMetrics) IncrementLSTYieldErrors(lstName string) {
	om.LSTYieldErrors.WithLabelValues(lstName).Inc()
}

// IncrementRPCCalls increments the RPC calls counter
func (om *OperatorMetrics) IncrementRPCCalls(method, status string) {
	om.RPCCallsTotal.WithLabelValues(method, status).Inc()
}

// ObserveRPCCallDuration observes the duration of an RPC call
func (om *OperatorMetrics) ObserveRPCCallDuration(method string, duration float64) {
	om.RPCCallDuration.WithLabelValues(method).Observe(duration)
}

// SetOperatorUptime sets the operator uptime
func (om *OperatorMetrics) SetOperatorUptime(uptime float64) {
	om.OperatorUptime.Set(uptime)
}

// SetLastTaskProcessed sets the last processed task number
func (om *OperatorMetrics) SetLastTaskProcessed(taskNum float64) {
	om.LastTaskProcessed.Set(taskNum)
}

// SetLastYieldUpdate sets the last yield update timestamp
func (om *OperatorMetrics) SetLastYieldUpdate(lstName string, timestamp float64) {
	om.LastYieldUpdate.WithLabelValues(lstName).Set(timestamp)
}
