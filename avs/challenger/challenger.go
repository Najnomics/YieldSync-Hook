package challenger

import (
	"context"
	"fmt"
	"time"

	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"

	"github.com/Layr-Labs/eigensdk-go/chainio/clients"
	sdkclients "github.com/Layr-Labs/eigensdk-go/chainio/clients"
	"github.com/Layr-Labs/eigensdk-go/services/avsregistry"
	"github.com/Layr-Labs/eigensdk-go/services/operatorsinfo"
	oprsinfoserv "github.com/Layr-Labs/eigensdk-go/services/operatorsinfo"
	"github.com/YieldSync/yieldsync-operator/challenger/types"
	"github.com/YieldSync/yieldsync-operator/core"
	"github.com/YieldSync/yieldsync-operator/core/chainio"
	"github.com/YieldSync/yieldsync-operator/core/config"

	yieldsynctaskmanager "github.com/YieldSync/yieldsync-operator/contracts/bindings/YieldSyncTaskManager"
)

const (
	avsName = "yieldsync"
)

// Challenger verifies task responses and submits challenges for incorrect responses
type Challenger struct {
	config    config.Config
	logger    logging.Logger
	ethClient *ethclient.Client

	// EigenLayer clients
	elClients  *clients.Clients
	elContracts *sdkclients.Clients

	// YieldSync contracts
	yieldSyncContracts *chainio.YieldSyncContracts

	// Operators info service
	operatorsInfoService operatorsinfo.OperatorsInfoService

	// AVS registry service
	avsRegistryService avsregistry.AvsRegistryService

	// LST monitors for verification
	lstMonitors map[string]*core.LSTMonitor

	// Challenge tracking
	challengeWindow time.Duration

	// Context and cancellation
	ctx    context.Context
	cancel context.CancelFunc
}

// NewChallenger creates a new challenger
func NewChallenger(config config.Config) (*Challenger, error) {
	ctx, cancel := context.WithCancel(context.Background())

	// Setup logger
	logger := config.Logger

	// Setup Ethereum client
	ethClient := &config.EthHttpClient

	// Setup EigenLayer clients
	elClients, err := clients.NewClients(
		config.EthHttpRpcUrl,
		config.EthWsRpcUrl,
		config.AggregatorAddress,
		ethClient,
	)
	if err != nil {
		cancel()
		return nil, err
	}

	// Setup EigenLayer contracts
	elContracts, err := sdkclients.NewClients(
		config.IncredibleSquaringServiceManager,
		config.DelegationManagerAddr,
		config.TokenStrategyAddr,
		config.AggregatorAddress,
		elClients,
	)
	if err != nil {
		cancel()
		return nil, err
	}

	// Setup YieldSync contracts
	yieldSyncContracts, err := chainio.NewYieldSyncContracts(
		config.IncredibleSquaringServiceManager,
		config.IncredibleSquaringRegistryCoordinatorAddr,
		ethClient,
	)
	if err != nil {
		cancel()
		return nil, err
	}

	// Setup operators info service
	operatorsInfoService := oprsinfoserv.NewOperatorsInfoServiceInMemory(
		elClients,
		logger,
	)

	// Setup AVS registry service
	avsRegistryService := avsregistry.NewAvsRegistryService(
		elClients,
		logger,
	)

	// Setup LST monitors
	lstMonitors := make(map[string]*core.LSTMonitor)
	lstMonitors["stETH"] = core.NewLSTMonitor("stETH", "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84", logger)
	lstMonitors["rETH"] = core.NewLSTMonitor("rETH", "0xae78736Cd615f374D3085123A210448E74Fc6393", logger)
	lstMonitors["cbETH"] = core.NewLSTMonitor("cbETH", "0xBe9895146f7AF43049ca1c1AE358B0541Ea49704", logger)
	lstMonitors["sfrxETH"] = core.NewLSTMonitor("sfrxETH", "0xac3E018457B222d93114458476f3E3416Abbe38F", logger)

	challenger := &Challenger{
		config:               config,
		logger:               logger,
		ethClient:            ethClient,
		elClients:            elClients,
		elContracts:          elContracts,
		yieldSyncContracts:   yieldSyncContracts,
		operatorsInfoService:  operatorsInfoService,
		avsRegistryService:   avsRegistryService,
		lstMonitors:          lstMonitors,
		challengeWindow:      100 * 12 * time.Second, // 100 blocks * 12 seconds per block
		ctx:                  ctx,
		cancel:               cancel,
	}

	return challenger, nil
}

// Start starts the challenger
func (c *Challenger) Start(ctx context.Context) error {
	c.logger.Info("Starting YieldSync Challenger")

	// Start task response monitoring
	go c.monitorTaskResponses()

	// Start challenge processing
	go c.processChallenges()

	// Wait for context cancellation
	<-ctx.Done()

	c.logger.Info("Shutting down YieldSync Challenger")
	return nil
}

// Stop stops the challenger
func (c *Challenger) Stop() {
	c.logger.Info("Stopping YieldSync Challenger")
	c.cancel()
}

// monitorTaskResponses monitors for new task responses
func (c *Challenger) monitorTaskResponses() {
	c.logger.Info("Starting task response monitoring")

	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-c.ctx.Done():
			c.logger.Info("Task response monitoring stopped")
			return
		case <-ticker.C:
			if err := c.checkForNewResponses(); err != nil {
				c.logger.Error("Error checking for new responses", "error", err)
			}
		}
	}
}

// checkForNewResponses checks for new task responses
func (c *Challenger) checkForNewResponses() error {
	// Get the latest task number
	latestTaskNum, err := c.yieldSyncContracts.TaskManager.LatestTaskNum(nil)
	if err != nil {
		return err
	}

	// Check each task for responses
	for taskNum := uint32(0); taskNum <= latestTaskNum; taskNum++ {
		if err := c.checkTaskResponse(taskNum); err != nil {
			c.logger.Error("Error checking task response", "taskNum", taskNum, "error", err)
			continue
		}
	}

	return nil
}

// checkTaskResponse checks a specific task response
func (c *Challenger) checkTaskResponse(taskNum uint32) error {
	// Check if task has been responded to
	taskResponseHash, err := c.yieldSyncContracts.TaskManager.AllTaskResponses(nil, taskNum)
	if err != nil {
		return err
	}

	if taskResponseHash == [32]byte{} {
		// No response yet
		return nil
	}

	// Check if already challenged
	alreadyChallenged, err := c.yieldSyncContracts.TaskManager.TaskSuccessfullyChallenged(nil, taskNum)
	if err != nil {
		return err
	}

	if alreadyChallenged {
		// Already challenged
		return nil
	}

	// Check if within challenge window
	taskHash, err := c.yieldSyncContracts.TaskManager.AllTaskHashes(nil, taskNum)
	if err != nil {
		return err
	}

	// This would decode the task to get the creation block
	// For now, assume it's within the challenge window
	if err := c.verifyTaskResponse(taskNum); err != nil {
		c.logger.Info("Task response verification failed", "taskNum", taskNum, "error", err)
		if err := c.submitChallenge(taskNum); err != nil {
			c.logger.Error("Error submitting challenge", "taskNum", taskNum, "error", err)
			return err
		}
	}

	return nil
}

// verifyTaskResponse verifies a task response
func (c *Challenger) verifyTaskResponse(taskNum uint32) error {
	// Get task details
	taskHash, err := c.yieldSyncContracts.TaskManager.AllTaskHashes(nil, taskNum)
	if err != nil {
		return err
	}

	// This would decode the task to get the LST token
	// For now, assume it's stETH
	lstMonitor, exists := c.lstMonitors["stETH"]
	if !exists {
		return fmt.Errorf("no monitor found for LST token")
	}

	// Get the actual yield rate from the LST monitor
	actualYieldData, err := lstMonitor.GetLatestYieldData()
	if err != nil {
		return fmt.Errorf("failed to get actual yield data: %w", err)
	}

	// This would get the reported yield rate from the task response
	// For now, assume it's incorrect if it's not within 1% of the actual rate
	reportedYieldRate := uint32(300) // This would come from the actual task response
	
	if abs(int(actualYieldData.YieldRate) - int(reportedYieldRate)) > 10 { // 0.1% tolerance
		return fmt.Errorf("yield rate mismatch: reported %d, actual %d", reportedYieldRate, actualYieldData.YieldRate)
	}

	return nil
}

// submitChallenge submits a challenge for an incorrect task response
func (c *Challenger) submitChallenge(taskNum uint32) error {
	c.logger.Info("Submitting challenge", "taskNum", taskNum)

	// Get task details
	taskHash, err := c.yieldSyncContracts.TaskManager.AllTaskHashes(nil, taskNum)
	if err != nil {
		return err
	}

	// Create task struct (this would be decoded from the hash)
	task := yieldsynctaskmanager.IYieldSyncTaskManagerTask{
		LstToken:                "stETH",
		TaskCreatedBlock:        uint32(time.Now().Unix()),
		QuorumNumbers:           []byte{0},
		QuorumThresholdPercentage: 50,
	}

	// Create task response struct (this would be decoded from the response hash)
	taskResponse := yieldsynctaskmanager.IYieldSyncTaskManagerTaskResponse{
		ReferenceTaskIndex: taskNum,
		YieldRate:          300, // This would be the incorrect reported rate
		Timestamp:          uint32(time.Now().Unix()),
		DataHash:           "0x",
	}

	// Create task response metadata struct
	taskResponseMetadata := yieldsynctaskmanager.IYieldSyncTaskManagerTaskResponseMetadata{
		TaskRespondedBlock: uint32(time.Now().Unix()),
		HashOfNonSigners:   [32]byte{},
	}

	// Create non-signing operators pubkeys (this would be the actual non-signers)
	pubkeysOfNonSigningOperators := []yieldsynctaskmanager.BN254G1Point{}

	// Submit challenge
	tx, err := c.yieldSyncContracts.TaskManager.RaiseAndResolveChallenge(
		c.config.SignerFn,
		task,
		taskResponse,
		taskResponseMetadata,
		pubkeysOfNonSigningOperators,
	)
	if err != nil {
		return err
	}

	c.logger.Info("Challenge submitted", "txHash", tx.Hash().Hex())
	return nil
}

// processChallenges processes challenges
func (c *Challenger) processChallenges() {
	c.logger.Info("Starting challenge processing")

	// This would implement challenge processing logic
	// For now, just log that it's running
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-c.ctx.Done():
			c.logger.Info("Challenge processing stopped")
			return
		case <-ticker.C:
			c.logger.Info("Challenge processing active")
		}
	}
}

// abs returns the absolute value of an integer
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
