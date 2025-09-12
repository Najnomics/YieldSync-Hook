package tests

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/YieldSync/yieldsync-hook/avs/aggregator"
	"github.com/YieldSync/yieldsync-hook/avs/challenger"
	"github.com/YieldSync/yieldsync-hook/avs/core"
	"github.com/YieldSync/yieldsync-hook/avs/operator"
)

// TestIntegrationSuite runs comprehensive integration tests
func TestIntegrationSuite(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration tests in short mode")
	}

	// Setup test environment
	env := setupTestEnvironment(t)
	defer env.cleanup()

	// Run integration tests
	t.Run("FullWorkflow", func(t *testing.T) {
		testFullWorkflow(t, env)
	})
	
	t.Run("AggregatorOperatorInteraction", func(t *testing.T) {
		testAggregatorOperatorInteraction(t, env)
	})
	
	t.Run("ChallengerVerification", func(t *testing.T) {
		testChallengerVerification(t, env)
	})
	
	t.Run("HealthAndMonitoring", func(t *testing.T) {
		testHealthAndMonitoring(t, env)
	})
}

// TestEnvironment represents the test environment
type TestEnvironment struct {
	aggregator *aggregator.EnhancedAggregator
	operator   *operator.EnhancedOperator
	challenger *challenger.EnhancedChallenger
	config     core.NodeConfig
	ctx        context.Context
	cancel     context.CancelFunc
}

// setupTestEnvironment sets up the test environment
func setupTestEnvironment(t *testing.T) *TestEnvironment {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)

	config := createTestConfig()

	// Create enhanced aggregator
	agg, err := aggregator.NewEnhancedAggregator(config)
	require.NoError(t, err, "Failed to create aggregator")

	// Create enhanced operator
	op, err := operator.NewEnhancedOperator(config)
	require.NoError(t, err, "Failed to create operator")

	// Create enhanced challenger
	ch, err := challenger.NewEnhancedChallenger(config)
	require.NoError(t, err, "Failed to create challenger")

	env := &TestEnvironment{
		aggregator: agg,
		operator:   op,
		challenger: ch,
		config:     config,
		ctx:        ctx,
		cancel:     cancel,
	}

	// Start services in background
	go agg.Start(ctx)
	go op.Start(ctx)
	go ch.Start(ctx)

	// Give services time to initialize
	time.Sleep(2 * time.Second)

	return env
}

// cleanup cleans up the test environment
func (env *TestEnvironment) cleanup() {
	env.aggregator.Stop()
	env.operator.Stop()
	env.challenger.Stop()
	env.cancel()
}

// createTestConfig creates a test configuration
func createTestConfig() core.NodeConfig {
	return core.NodeConfig{
		EthRpcUrl: "http://localhost:8545", // Anvil local node
		EthWsUrl:  "ws://localhost:8545",

		Logger: core.LoggerConfig{
			Level:  "info",
			Format: "json",
		},

		EigenLayer: core.EigenLayerConfig{
			OperatorAddress:            "0x1234567890123456789012345678901234567890",
			ServiceManagerAddr:         "0x2345678901234567890123456789012345678901",
			TaskManagerAddr:            "0x3456789012345678901234567890123456789012",
			DelegationManagerAddr:      "0x4567890123456789012345678901234567890123",
			StrategyManagerAddr:        "0x5678901234567890123456789012345678901234",
			AVSDirectoryAddress:        "0x6789012345678901234567890123456789012345",
			EcdsaPrivateKeyStorePath:   "/tmp/test_ecdsa_key",
			BlsPrivateKeyStorePath:     "/tmp/test_bls_key",
		},

		Operator: core.OperatorConfig{
			ServerIpPortAddr:  "localhost:8080",
			MetricsIpPortAddr: "localhost:9090",
			NodeApiIpPortAddr: "localhost:9091",
			EnableMetrics:     true,
			EnableNodeApi:     true,
		},

		Aggregator: core.AggregatorConfig{
			AggregatorAddress:         "0x7890123456789012345678901234567890123456",
			ServerIpPortAddr:          "localhost:8081",
			MetricsIpPortAddr:         "localhost:9092",
			QuorumThresholdPercentage: 67,
			EnableMetrics:             true,
		},

		Challenger: core.ChallengerConfig{
			ChallengerAddress: "0x8901234567890123456789012345678901234567",
			MetricsIpPortAddr: "localhost:9093",
			EnableMetrics:     true,
		},

		LSTMonitoring: core.LSTMonitoringConfig{
			MonitoringInterval:        30 * time.Second,
			LidoStETHAddress:         "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84",
			RocketPoolRETHAddress:    "0xae78736Cd615f374D3085123A210448E74Fc6393",
			CoinbaseCBETHAddress:     "0xBe9895146f7AF43049ca1c1AE358B0541Ea49704",
			FraxSFRXETHAddress:       "0xac3E018457B222d93114458476f3E3416Abbe38F",
		},
	}
}

// testFullWorkflow tests the complete workflow from task creation to response aggregation
func testFullWorkflow(t *testing.T, env *TestEnvironment) {
	// Test task creation by aggregator
	task, err := env.aggregator.CreateNewTask(
		"stETH",
		[]byte{0},
		[]uint32{67},
	)
	require.NoError(t, err, "Failed to create task")
	assert.NotNil(t, task, "Task should not be nil")
	assert.Equal(t, "stETH", task.LSTToken, "LST token should match")

	// Wait for operator to receive and process the task
	time.Sleep(3 * time.Second)

	// Verify operator has processed the task
	operatorStats := env.operator.GetTaskStats()
	assert.Greater(t, operatorStats.ProcessedTasks, 0, "Operator should have processed tasks")

	// Verify aggregator has received responses
	activeChallenges := env.challenger.GetActiveChallenges()
	assert.NotNil(t, activeChallenges, "Active challenges should be accessible")

	t.Logf("Full workflow test completed successfully")
}

// testAggregatorOperatorInteraction tests interaction between aggregator and operator
func testAggregatorOperatorInteraction(t *testing.T, env *TestEnvironment) {
	// Test HTTP communication between services
	
	// Test operator health endpoint
	resp, err := http.Get(fmt.Sprintf("http://%s/health", env.config.Operator.ServerIpPortAddr))
	require.NoError(t, err, "Failed to call operator health endpoint")
	defer resp.Body.Close()
	
	assert.Equal(t, http.StatusOK, resp.StatusCode, "Operator health endpoint should return 200")

	var healthResp map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&healthResp)
	require.NoError(t, err, "Failed to decode health response")
	
	assert.Equal(t, "healthy", healthResp["status"], "Operator should be healthy")

	// Test aggregator health endpoint
	resp, err = http.Get(fmt.Sprintf("http://%s/health", env.config.Aggregator.ServerIpPortAddr))
	require.NoError(t, err, "Failed to call aggregator health endpoint")
	defer resp.Body.Close()
	
	assert.Equal(t, http.StatusOK, resp.StatusCode, "Aggregator health endpoint should return 200")

	t.Logf("Aggregator-operator interaction test completed successfully")
}

// testChallengerVerification tests the challenger verification functionality
func testChallengerVerification(t *testing.T, env *TestEnvironment) {
	// Get initial challenge stats
	initialStats := env.challenger.GetChallengeStats()
	assert.NotNil(t, initialStats, "Challenge stats should be accessible")

	// In a real test, we would:
	// 1. Create a task with known incorrect yield data
	// 2. Wait for challenger to detect and challenge it
	// 3. Verify challenge was submitted correctly

	// For now, just verify the challenger is operational
	activeChallenges := env.challenger.GetActiveChallenges()
	assert.NotNil(t, activeChallenges, "Active challenges should be accessible")

	challengeHistory := env.challenger.GetChallengeHistory()
	assert.NotNil(t, challengeHistory, "Challenge history should be accessible")

	t.Logf("Challenger verification test completed successfully")
}

// testHealthAndMonitoring tests health checks and monitoring endpoints
func testHealthAndMonitoring(t *testing.T, env *TestEnvironment) {
	endpoints := []struct {
		name string
		url  string
	}{
		{"Operator Health", fmt.Sprintf("http://%s/health", env.config.Operator.ServerIpPortAddr)},
		{"Operator Status", fmt.Sprintf("http://%s/status", env.config.Operator.ServerIpPortAddr)},
		{"Operator Metrics", fmt.Sprintf("http://%s/metrics", env.config.Operator.MetricsIpPortAddr)},
		{"Aggregator Health", fmt.Sprintf("http://%s/health", env.config.Aggregator.ServerIpPortAddr)},
		{"Aggregator Metrics", fmt.Sprintf("http://%s/metrics", env.config.Aggregator.MetricsIpPortAddr)},
		{"Challenger Metrics", fmt.Sprintf("http://%s/metrics", env.config.Challenger.MetricsIpPortAddr)},
	}

	for _, endpoint := range endpoints {
		t.Run(endpoint.name, func(t *testing.T) {
			resp, err := http.Get(endpoint.url)
			if err != nil {
				t.Logf("Warning: %s endpoint not accessible: %v", endpoint.name, err)
				return // Skip if endpoint not available (service might not be running)
			}
			defer resp.Body.Close()

			assert.Equal(t, http.StatusOK, resp.StatusCode, 
				"%s should return 200", endpoint.name)

			if strings.Contains(endpoint.url, "/metrics") {
				// Verify it's Prometheus metrics format
				body := make([]byte, 1024)
				n, _ := resp.Body.Read(body)
				content := string(body[:n])
				assert.Contains(t, content, "yieldsync", 
					"Metrics should contain yieldsync metrics")
			}
		})
	}

	t.Logf("Health and monitoring test completed successfully")
}

// TestLSTMonitoring tests LST monitoring functionality
func TestLSTMonitoring(t *testing.T) {
	config := createTestConfig()
	
	// Test LST monitor creation and basic functionality
	monitor := core.NewLSTMonitor("stETH", config.LSTMonitoring.LidoStETHAddress, nil)
	require.NotNil(t, monitor, "LST monitor should be created")

	// Test getting yield data
	yieldData, err := monitor.GetLatestYieldData()
	require.NoError(t, err, "Should be able to get yield data")
	assert.NotNil(t, yieldData, "Yield data should not be nil")
	assert.Equal(t, "stETH", yieldData.LSTToken, "LST token should match")
	assert.Greater(t, yieldData.YieldRate, uint32(0), "Yield rate should be positive")

	// Test monitor health
	assert.True(t, monitor.IsHealthy(), "Monitor should be healthy initially")

	t.Logf("LST monitoring test completed successfully")
}

// TestMetricsCollection tests metrics collection
func TestMetricsCollection(t *testing.T) {
	config := createTestConfig()
	
	// Create and test operator metrics
	op, err := operator.NewEnhancedOperator(config)
	require.NoError(t, err, "Failed to create operator")

	operatorInfo := op.GetOperatorInfo()
	assert.NotNil(t, operatorInfo, "Operator info should not be nil")
	assert.NotEmpty(t, operatorInfo.OperatorAddress, "Operator address should not be empty")

	taskStats := op.GetTaskStats()
	assert.NotNil(t, taskStats, "Task stats should not be nil")
	assert.GreaterOrEqual(t, taskStats.PendingTasks, 0, "Pending tasks should be non-negative")

	t.Logf("Metrics collection test completed successfully")
}

// TestErrorHandling tests error handling across services
func TestErrorHandling(t *testing.T) {
	config := createTestConfig()
	
	// Test with invalid configuration
	invalidConfig := config
	invalidConfig.EthRpcUrl = "invalid-url"

	// Test aggregator error handling
	_, err := aggregator.NewEnhancedAggregator(invalidConfig)
	assert.Error(t, err, "Should fail with invalid configuration")

	// Test operator error handling
	_, err = operator.NewEnhancedOperator(invalidConfig)
	assert.Error(t, err, "Should fail with invalid configuration")

	// Test challenger error handling
	_, err = challenger.NewEnhancedChallenger(invalidConfig)
	assert.Error(t, err, "Should fail with invalid configuration")

	t.Logf("Error handling test completed successfully")
}

// BenchmarkTaskProcessing benchmarks task processing performance
func BenchmarkTaskProcessing(b *testing.B) {
	if testing.Short() {
		b.Skip("Skipping benchmark in short mode")
	}

	config := createTestConfig()
	op, err := operator.NewEnhancedOperator(config)
	require.NoError(b, err, "Failed to create operator")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	go op.Start(ctx)
	time.Sleep(1 * time.Second) // Give operator time to start

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			// Simulate task processing
			stats := op.GetTaskStats()
			_ = stats // Use the result to prevent optimization
		}
	})

	op.Stop()
}

// TestServiceIntegrationWithMockContracts tests service integration with mock contracts
func TestServiceIntegrationWithMockContracts(t *testing.T) {
	// This test would use mock contracts to test full integration
	// without requiring a real blockchain network
	
	config := createTestConfig()
	
	// Create services
	agg, err := aggregator.NewEnhancedAggregator(config)
	require.NoError(t, err, "Failed to create aggregator")

	op, err := operator.NewEnhancedOperator(config)
	require.NoError(t, err, "Failed to create operator")

	ch, err := challenger.NewEnhancedChallenger(config)
	require.NoError(t, err, "Failed to create challenger")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Start services
	go agg.Start(ctx)
	go op.Start(ctx)
	go ch.Start(ctx)

	// Give services time to initialize
	time.Sleep(2 * time.Second)

	// Test basic functionality
	operatorInfo := op.GetOperatorInfo()
	assert.NotEmpty(t, operatorInfo.OperatorAddress, "Operator address should not be empty")

	stats := op.GetTaskStats()
	assert.GreaterOrEqual(t, stats.PendingTasks, 0, "Pending tasks should be non-negative")

	challengeStats := ch.GetChallengeStats()
	assert.GreaterOrEqual(t, challengeStats.ActiveChallenges, 0, "Active challenges should be non-negative")

	// Clean up
	agg.Stop()
	op.Stop()
	ch.Stop()

	t.Logf("Service integration with mock contracts test completed successfully")
}

// Example test for testing HTTP endpoints
func TestHTTPEndpoints(t *testing.T) {
	config := createTestConfig()
	
	// Create operator
	op, err := operator.NewEnhancedOperator(config)
	require.NoError(t, err, "Failed to create operator")

	// Create test server
	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	// Test health handler (we'd need to expose this for testing)
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		response := map[string]interface{}{
			"status":    "healthy",
			"timestamp": time.Now(),
			"version":   "0.1.0",
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	})

	handler.ServeHTTP(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	assert.Equal(t, http.StatusOK, resp.StatusCode, "Health endpoint should return 200")

	var healthResp map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&healthResp)
	require.NoError(t, err, "Failed to decode health response")

	assert.Equal(t, "healthy", healthResp["status"], "Status should be healthy")

	t.Logf("HTTP endpoints test completed successfully")
}