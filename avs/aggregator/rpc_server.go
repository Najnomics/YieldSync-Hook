package aggregator

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/YieldSync/yieldsync-operator/aggregator/types"
	"github.com/Layr-Labs/eigensdk-go/logging"
)

// RPCServer handles RPC communication with operators
type RPCServer struct {
	server      *http.Server
	logger      logging.Logger
	responseChan chan *types.TaskResponseWithSignature
}

// NewRPCServer creates a new RPC server
func NewRPCServer(address string, logger logging.Logger) *RPCServer {
	router := mux.NewRouter()
	
	server := &http.Server{
		Addr:    address,
		Handler: router,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	rpcServer := &RPCServer{
		server:      server,
		logger:      logger,
		responseChan: make(chan *types.TaskResponseWithSignature, 100),
	}

	// Setup routes
	rpcServer.setupRoutes(router)

	return rpcServer
}

// Start starts the RPC server
func (rs *RPCServer) Start(ctx context.Context) error {
	rs.logger.Info("Starting RPC server", "address", rs.server.Addr)

	go func() {
		if err := rs.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			rs.logger.Error("RPC server error", "error", err)
		}
	}()

	// Wait for context cancellation
	<-ctx.Done()

	// Shutdown server
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := rs.server.Shutdown(shutdownCtx); err != nil {
		rs.logger.Error("Error shutting down RPC server", "error", err)
		return err
	}

	rs.logger.Info("RPC server stopped")
	return nil
}

// setupRoutes sets up the HTTP routes
func (rs *RPCServer) setupRoutes(router *mux.Router) {
	// Health check endpoint
	router.HandleFunc("/health", rs.handleHealthCheck).Methods("GET")

	// Task response endpoint
	router.HandleFunc("/task-response", rs.handleTaskResponse).Methods("POST")

	// Metrics endpoint
	router.HandleFunc("/metrics", rs.handleMetrics).Methods("GET")

	// Create task endpoint
	router.HandleFunc("/create-task", rs.handleCreateTask).Methods("POST")

	// Get tasks endpoint
	router.HandleFunc("/tasks", rs.handleGetTasks).Methods("GET")
}

// handleHealthCheck handles health check requests
func (rs *RPCServer) handleHealthCheck(w http.ResponseWriter, r *http.Request) {
	response := types.HealthCheckResponse{
		Status:    "healthy",
		Timestamp: time.Now(),
		Uptime:    "0s", // This would be calculated from start time
		Version:   "0.1.0",
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		rs.logger.Error("Error encoding health check response", "error", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
}

// handleTaskResponse handles task response requests
func (rs *RPCServer) handleTaskResponse(w http.ResponseWriter, r *http.Request) {
	var request types.TaskResponseWithSignature
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		rs.logger.Error("Error decoding task response", "error", err)
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}

	// Set timestamp if not provided
	if request.Timestamp.IsZero() {
		request.Timestamp = time.Now()
	}

	// Send to response channel
	select {
	case rs.responseChan <- &request:
		rs.logger.Info("Task response received", 
			"taskIndex", request.TaskResponse.ReferenceTaskIndex,
			"operator", request.OperatorAddress,
		)
	default:
		rs.logger.Error("Response channel full, dropping response")
		http.Error(w, "Service Unavailable", http.StatusServiceUnavailable)
		return
	}

	// Send success response
	response := map[string]interface{}{
		"success": true,
		"message": "Task response received",
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		rs.logger.Error("Error encoding response", "error", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
}

// handleMetrics handles metrics requests
func (rs *RPCServer) handleMetrics(w http.ResponseWriter, r *http.Request) {
	response := types.MetricsResponse{
		TasksCreated:       0, // This would be tracked
		ResponsesProcessed: 0, // This would be tracked
		ActiveOperators:    0, // This would be tracked
		LastTaskTime:       time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		rs.logger.Error("Error encoding metrics response", "error", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
}

// handleCreateTask handles create task requests
func (rs *RPCServer) handleCreateTask(w http.ResponseWriter, r *http.Request) {
	var request types.TaskCreationRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		rs.logger.Error("Error decoding create task request", "error", err)
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}

	// This would create a new task
	// For now, return a mock response
	response := types.TaskCreationResponse{
		TaskIndex: 1,
		Success:   true,
		Message:   "Task created successfully",
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		rs.logger.Error("Error encoding create task response", "error", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
}

// handleGetTasks handles get tasks requests
func (rs *RPCServer) handleGetTasks(w http.ResponseWriter, r *http.Request) {
	// This would return a list of tasks
	// For now, return an empty list
	tasks := []interface{}{}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(tasks); err != nil {
		rs.logger.Error("Error encoding get tasks response", "error", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
}

// GetResponseChan returns the response channel
func (rs *RPCServer) GetResponseChan() <-chan *types.TaskResponseWithSignature {
	return rs.responseChan
}
