package operator

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/prometheus/client_golang/prometheus"

	"github.com/YieldSync/yieldsync-operator/chainio"
	"github.com/YieldSync/yieldsync-operator/core"
	"github.com/YieldSync/yieldsync-operator/metrics"
	"github.com/YieldSync/yieldsync-operator/types"

	"github.com/Layr-Labs/eigensdk-go/chainio/clients"
	sdkelcontracts "github.com/Layr-Labs/eigensdk-go/chainio/clients/elcontracts"
	"github.com/Layr-Labs/eigensdk-go/chainio/clients/eth"
	"github.com/Layr-Labs/eigensdk-go/chainio/clients/wallet"
	"github.com/Layr-Labs/eigensdk-go/chainio/txmgr"
	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	sdkecdsa "github.com/Layr-Labs/eigensdk-go/crypto/ecdsa"
	sdklogging "github.com/Layr-Labs/eigensdk-go/logging"
	sdkmetrics "github.com/Layr-Labs/eigensdk-go/metrics"
	"github.com/Layr-Labs/eigensdk-go/metrics/collectors/economic"
	rpccalls "github.com/Layr-Labs/eigensdk-go/metrics/collectors/rpc_calls"
	"github.com/Layr-Labs/eigensdk-go/nodeapi"
	"github.com/Layr-Labs/eigensdk-go/signerv2"
	sdktypes "github.com/Layr-Labs/eigensdk-go/types"
)

const AVS_NAME = "yieldsync"
const SEM_VER = "0.1.0"

type Operator struct {
	config    types.NodeConfig
	logger    sdklogging.Logger
	ethClient chainio.EthClientInterface
	
	// EigenLayer clients
	elClients *clients.Clients
	elContracts *sdkelcontracts.Clients
	
	// YieldSync contracts
	yieldSyncContracts *chainio.YieldSyncContracts
	
	// Operator info
	operatorInfo types.OperatorInfo
	
	// Metrics
	metrics *metrics.OperatorMetrics
	
	// Task monitoring
	taskMonitor *core.TaskMonitor
	
	// LST monitors
	lstMonitors map[string]*core.LSTMonitor
	
	// RPC client for aggregator communication
	rpcClient *chainio.RPCClient
	
	// Context and cancellation
	ctx    context.Context
	cancel context.CancelFunc
}

// NewOperatorFromConfig creates a new operator from configuration
func NewOperatorFromConfig(config types.NodeConfig) (*Operator, error) {
	ctx, cancel := context.WithCancel(context.Background())
	
	// Setup logger
	logger, err := sdklogging.NewZapLogger(config.Logger.Level)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create logger: %w", err)
	}
	
	// Setup Ethereum client
	ethClient, err := eth.NewClient(config.EthRpcUrl, config.EthWsUrl)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create eth client: %w", err)
	}
	
	// Setup wallet
	ecdsaKeyPair, err := sdkecdsa.ReadKey(config.EigenLayer.EcdsaPrivateKeyStorePath)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to read ecdsa key: %w", err)
	}
	
	blsKeyPair, err := bls.ReadPrivateKeyFromFile(config.EigenLayer.BlsPrivateKeyStorePath)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to read bls key: %w", err)
	}
	
	wallet, err := wallet.NewWallet(ecdsaKeyPair, common.HexToAddress(config.Address))
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create wallet: %w", err)
	}
	
	// Setup EigenLayer clients
	elClients, err := clients.NewClients(
		config.EthRpcUrl,
		config.EthWsUrl,
		common.HexToAddress(config.EigenLayer.OperatorAddress),
		ethClient,
	)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create el clients: %w", err)
	}
	
	// Setup EigenLayer contracts
	elContracts, err := sdkelcontracts.NewClients(
		common.HexToAddress(config.EigenLayer.ServiceManagerAddr),
		common.HexToAddress(config.EigenLayer.DelegationManagerAddr),
		common.HexToAddress(config.EigenLayer.StrategyManagerAddr),
		common.HexToAddress(config.EigenLayer.AVSDirectoryAddress),
		elClients,
	)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create el contracts: %w", err)
	}
	
	// Setup YieldSync contracts
	yieldSyncContracts, err := chainio.NewYieldSyncContracts(
		common.HexToAddress(config.EigenLayer.ServiceManagerAddr),
		common.HexToAddress(config.EigenLayer.TaskManagerAddr),
		ethClient,
	)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to create yieldsync contracts: %w", err)
	}
	
	// Setup metrics
	operatorMetrics := metrics.NewOperatorMetrics(AVS_NAME, SEM_VER)
	
	// Setup RPC client
	rpcClient := chainio.NewRPCClient(config.Aggregator.ServerIpPortAddr, logger)
	
	// Setup LST monitors
	lstMonitors := make(map[string]*core.LSTMonitor)
	lstMonitors["stETH"] = core.NewLSTMonitor("stETH", config.LSTMonitoring.LidoStETHAddress, logger)
	lstMonitors["rETH"] = core.NewLSTMonitor("rETH", config.LSTMonitoring.RocketPoolRETHAddress, logger)
	lstMonitors["cbETH"] = core.NewLSTMonitor("cbETH", config.LSTMonitoring.CoinbaseCBETHAddress, logger)
	lstMonitors["sfrxETH"] = core.NewLSTMonitor("sfrxETH", config.LSTMonitoring.FraxSFRXETHAddress, logger)
	
	// Setup task monitor
	taskMonitor := core.NewTaskMonitor(
		yieldSyncContracts,
		lstMonitors,
		blsKeyPair,
		rpcClient,
		logger,
		operatorMetrics,
	)
	
	// Get operator info
	operatorId, err := elClients.AvsRegistryCoordinator.GetOperatorId(&bind.CallOpts{}, common.HexToAddress(config.EigenLayer.OperatorAddress))
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to get operator id: %w", err)
	}
	
	operatorInfo := types.OperatorInfo{
		OperatorAddress: config.EigenLayer.OperatorAddress,
		OperatorId:      operatorId,
		BlsKeypair:      blsKeyPair,
	}
	
	operator := &Operator{
		config:             config,
		logger:             logger,
		ethClient:          ethClient,
		elClients:          elClients,
		elContracts:        elContracts,
		yieldSyncContracts: yieldSyncContracts,
		operatorInfo:       operatorInfo,
		metrics:            operatorMetrics,
		taskMonitor:        taskMonitor,
		lstMonitors:        lstMonitors,
		rpcClient:          rpcClient,
		ctx:                ctx,
		cancel:             cancel,
	}
	
	return operator, nil
}

// Start starts the operator
func (o *Operator) Start(ctx context.Context) error {
	o.logger.Info("Starting YieldSync Operator", "operatorAddress", o.operatorInfo.OperatorAddress)
	
	// Start task monitoring
	go o.taskMonitor.Start(o.ctx)
	
	// Start LST monitoring
	for name, monitor := range o.lstMonitors {
		o.logger.Info("Starting LST monitor", "name", name)
		go monitor.Start(o.ctx, o.config.LSTMonitoring.MonitoringInterval)
	}
	
	// Start metrics server if enabled
	if o.config.Operator.EnableMetrics {
		go o.startMetricsServer()
	}
	
	// Start node API if enabled
	if o.config.Operator.EnableNodeApi {
		go o.startNodeAPI()
	}
	
	// Wait for context cancellation
	<-ctx.Done()
	
	o.logger.Info("Shutting down YieldSync Operator")
	return nil
}

// Stop stops the operator
func (o *Operator) Stop() {
	o.logger.Info("Stopping YieldSync Operator")
	o.cancel()
}

// startMetricsServer starts the metrics server
func (o *Operator) startMetricsServer() {
	// Implementation for metrics server
	o.logger.Info("Starting metrics server", "address", o.config.Operator.MetricsIpPortAddr)
	// Add metrics server implementation here
}

// startNodeAPI starts the node API server
func (o *Operator) startNodeAPI() {
	// Implementation for node API server
	o.logger.Info("Starting node API server", "address", o.config.Operator.NodeApiIpPortAddr)
	// Add node API implementation here
}

// GetOperatorInfo returns the operator information
func (o *Operator) GetOperatorInfo() types.OperatorInfo {
	return o.operatorInfo
}

// GetMetrics returns the operator metrics
func (o *Operator) GetMetrics() *metrics.OperatorMetrics {
	return o.metrics
}
