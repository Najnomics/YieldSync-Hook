package aggregator

import (
	"context"
	"math/big"
	"sync"
	"time"

	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"golang.org/x/crypto/sha3"

	"github.com/Layr-Labs/eigensdk-go/chainio/clients"
	sdkclients "github.com/Layr-Labs/eigensdk-go/chainio/clients"
	"github.com/Layr-Labs/eigensdk-go/services/avsregistry"
	blsagg "github.com/Layr-Labs/eigensdk-go/services/bls_aggregation"
	"github.com/Layr-Labs/eigensdk-go/services/operatorsinfo"
	oprsinfoserv "github.com/Layr-Labs/eigensdk-go/services/operatorsinfo"
	sdktypes "github.com/Layr-Labs/eigensdk-go/types"
	"github.com/YieldSync/yieldsync-operator/aggregator/types"
	"github.com/YieldSync/yieldsync-operator/core"
	"github.com/YieldSync/yieldsync-operator/core/chainio"
	"github.com/YieldSync/yieldsync-operator/core/config"

	yieldsynctaskmanager "github.com/YieldSync/yieldsync-operator/contracts/bindings/YieldSyncTaskManager"
)

const (
	// number of blocks after which a task is considered expired
	// this hardcoded here because it's also hardcoded in the contracts, but should
	// ideally be fetched from the contracts
	taskChallengeWindowBlock = 100
	blockTimeSeconds         = 12 * time.Second
	avsName                  = "yieldsync"
)

// Aggregator sends tasks (LST yield monitoring) onchain, then listens for operator signed TaskResponses.
// It aggregates responses signatures, and if any of the TaskResponses reaches the QuorumThresholdPercentage for each
// quorum (currently we only use a single quorum of the ERC20Mock token), it sends the aggregated TaskResponse and
// signature onchain.
//
// The signature is checked in the BLSSignatureChecker.sol contract, which expects a
//
//	struct NonSignerStakesAndSignature {
//		uint32[] nonSignerQuorumBitmapIndices;
//		BN254.G1Point[] nonSignerPubkeys;
//		BN254.G1Point[] quorumApks;
//		BN254.G2Point apkG2;
//		BN254.G1Point sigma;
//		uint32[] quorumApkIndices;
//		uint32[] quorumThresholdPercentages;
//		uint32[] quorumApkIndices;
//		uint32[] quorumThresholdPercentages;
//	}
type Aggregator struct {
	config    config.Config
	logger    logging.Logger
	ethClient chainio.EthClientInterface

	// EigenLayer clients
	elClients  *clients.Clients
	elContracts *sdkclients.Clients

	// YieldSync contracts
	yieldSyncContracts *chainio.YieldSyncContracts

	// BLS aggregation service
	blsAggregationService blsagg.BlsAggregationService

	// Operators info service
	operatorsInfoService operatorsinfo.OperatorsInfoService

	// AVS registry service
	avsRegistryService avsregistry.AvsRegistryService

	// Task tracking
	latestTaskNum   uint32
	taskCreatedChan chan yieldsynctaskmanager.ContractYieldSyncTaskManagerNewTaskCreated

	// RPC server for operator communication
	rpcServer *chainio.RPCServer

	// Context and cancellation
	ctx    context.Context
	cancel context.CancelFunc
}

// NewAggregator creates a new aggregator
func NewAggregator(config config.Config) (*Aggregator, error) {
	ctx, cancel := context.WithCancel(context.Background())

	// Setup logger
	logger := config.Logger

	// Setup Ethereum client
	ethClient := config.EthHttpClient

	// Setup EigenLayer clients
	elClients, err := clients.NewClients(
		config.EthHttpRpcUrl,
		config.EthWsRpcUrl,
		config.AggregatorAddress,
		&ethClient,
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
		&ethClient,
	)
	if err != nil {
		cancel()
		return nil, err
	}

	// Setup BLS aggregation service
	blsAggregationService := blsagg.NewBlsAggregationService(
		elClients,
		logger,
	)

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

	// Setup RPC server
	rpcServer := chainio.NewRPCServer(config.AggregatorServerIpPortAddr, logger)

	// Setup task tracking
	taskCreatedChan := make(chan yieldsynctaskmanager.ContractYieldSyncTaskManagerNewTaskCreated, 100)

	aggregator := &Aggregator{
		config:               config,
		logger:               logger,
		ethClient:            &ethClient,
		elClients:            elClients,
		elContracts:          elContracts,
		yieldSyncContracts:   yieldSyncContracts,
		blsAggregationService: blsAggregationService,
		operatorsInfoService:  operatorsInfoService,
		avsRegistryService:   avsRegistryService,
		latestTaskNum:        0,
		taskCreatedChan:      taskCreatedChan,
		rpcServer:            rpcServer,
		ctx:                  ctx,
		cancel:               cancel,
	}

	return aggregator, nil
}

// Start starts the aggregator
func (a *Aggregator) Start(ctx context.Context) error {
	a.logger.Info("Starting YieldSync Aggregator")

	// Start RPC server
	go a.rpcServer.Start(a.ctx)

	// Start task monitoring
	go a.monitorTasks()

	// Start response processing
	go a.processResponses()

	// Wait for context cancellation
	<-ctx.Done()

	a.logger.Info("Shutting down YieldSync Aggregator")
	return nil
}

// Stop stops the aggregator
func (a *Aggregator) Stop() {
	a.logger.Info("Stopping YieldSync Aggregator")
	a.cancel()
}

// CreateNewTask creates a new yield monitoring task
func (a *Aggregator) CreateNewTask(lstToken string, quorumThresholdPercentage uint32, quorumNumbers []byte) error {
	a.logger.Info("Creating new task", "lstToken", lstToken, "quorumThresholdPercentage", quorumThresholdPercentage)

	// Create task struct
	task := yieldsynctaskmanager.IYieldSyncTaskManagerTask{
		LstToken:                lstToken,
		TaskCreatedBlock:        uint32(time.Now().Unix()),
		QuorumNumbers:           quorumNumbers,
		QuorumThresholdPercentage: quorumThresholdPercentage,
	}

	// Submit task to contract
	tx, err := a.yieldSyncContracts.TaskManager.CreateNewTask(
		a.config.SignerFn,
		lstToken,
		quorumThresholdPercentage,
		quorumNumbers,
	)
	if err != nil {
		return err
	}

	a.logger.Info("Task created", "txHash", tx.Hash().Hex())
	return nil
}

// monitorTasks monitors for new tasks
func (a *Aggregator) monitorTasks() {
	a.logger.Info("Starting task monitoring")

	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-a.ctx.Done():
			a.logger.Info("Task monitoring stopped")
			return
		case <-ticker.C:
			if err := a.checkForNewTasks(); err != nil {
				a.logger.Error("Error checking for new tasks", "error", err)
			}
		}
	}
}

// checkForNewTasks checks for new tasks
func (a *Aggregator) checkForNewTasks() error {
	// Get the latest task number
	latestTaskNum, err := a.yieldSyncContracts.TaskManager.LatestTaskNum(nil)
	if err != nil {
		return err
	}

	// Check if there are new tasks
	if latestTaskNum <= a.latestTaskNum {
		return nil
	}

	a.logger.Info("New tasks detected", "latestTaskNum", latestTaskNum, "currentTaskNum", a.latestTaskNum)

	// Process new tasks
	for taskNum := a.latestTaskNum + 1; taskNum <= latestTaskNum; taskNum++ {
		if err := a.processNewTask(taskNum); err != nil {
			a.logger.Error("Error processing new task", "taskNum", taskNum, "error", err)
			continue
		}
	}

	a.latestTaskNum = latestTaskNum
	return nil
}

// processNewTask processes a new task
func (a *Aggregator) processNewTask(taskNum uint32) error {
	a.logger.Info("Processing new task", "taskNum", taskNum)

	// Get task details
	taskHash, err := a.yieldSyncContracts.TaskManager.AllTaskHashes(nil, taskNum)
	if err != nil {
		return err
	}

	a.logger.Info("Task details", "taskNum", taskNum, "taskHash", taskHash.Hex())

	// Emit task created event
	a.taskCreatedChan <- yieldsynctaskmanager.ContractYieldSyncTaskManagerNewTaskCreated{
		TaskIndex: taskNum,
		Task: yieldsynctaskmanager.IYieldSyncTaskManagerTask{
			LstToken:                "stETH", // This would come from the actual task data
			TaskCreatedBlock:        uint32(time.Now().Unix()),
			QuorumNumbers:           []byte{0},
			QuorumThresholdPercentage: 50,
		},
	}

	return nil
}

// processResponses processes operator responses
func (a *Aggregator) processResponses() {
	a.logger.Info("Starting response processing")

	for {
		select {
		case <-a.ctx.Done():
			a.logger.Info("Response processing stopped")
			return
		case response := <-a.rpcServer.GetResponseChan():
			if err := a.processOperatorResponse(response); err != nil {
				a.logger.Error("Error processing operator response", "error", err)
			}
		}
	}
}

// processOperatorResponse processes an operator response
func (a *Aggregator) processOperatorResponse(response *types.TaskResponseWithSignature) error {
	a.logger.Info("Processing operator response", "taskIndex", response.TaskResponse.ReferenceTaskIndex)

	// Verify the response
	if err := a.verifyResponse(response); err != nil {
		a.logger.Error("Response verification failed", "error", err)
		return err
	}

	// Aggregate signatures
	aggregatedSignature, err := a.aggregateSignatures(response)
	if err != nil {
		a.logger.Error("Signature aggregation failed", "error", err)
		return err
	}

	// Submit to contract
	if err := a.submitResponse(response, aggregatedSignature); err != nil {
		a.logger.Error("Response submission failed", "error", err)
		return err
	}

	a.logger.Info("Response processed successfully", "taskIndex", response.TaskResponse.ReferenceTaskIndex)
	return nil
}

// verifyResponse verifies an operator response
func (a *Aggregator) verifyResponse(response *types.TaskResponseWithSignature) error {
	// Verify the task exists
	taskHash, err := a.yieldSyncContracts.TaskManager.AllTaskHashes(nil, response.TaskResponse.ReferenceTaskIndex)
	if err != nil {
		return err
	}

	if taskHash == [32]byte{} {
		return fmt.Errorf("task does not exist")
	}

	// Verify the response hasn't been submitted yet
	existingResponse, err := a.yieldSyncContracts.TaskManager.AllTaskResponses(nil, response.TaskResponse.ReferenceTaskIndex)
	if err != nil {
		return err
	}

	if existingResponse != [32]byte{} {
		return fmt.Errorf("response already submitted")
	}

	// Verify the signature
	messageHash := a.createMessageHash(response.TaskResponse)
	if !a.verifySignature(messageHash, response.Signature, response.OperatorAddress) {
		return fmt.Errorf("invalid signature")
	}

	return nil
}

// aggregateSignatures aggregates operator signatures
func (a *Aggregator) aggregateSignatures(response *types.TaskResponseWithSignature) (*types.AggregatedSignature, error) {
	// This would implement BLS signature aggregation
	// For now, return a mock aggregated signature
	return &types.AggregatedSignature{
		NonSignerStakesAndSignature: types.NonSignerStakesAndSignature{
			NonSignerQuorumBitmapIndices: []uint32{},
			NonSignerPubkeys:            []types.G1Point{},
			QuorumApks:                  []types.G1Point{},
			ApkG2:                       types.G2Point{},
			Sigma:                       response.Signature,
			QuorumApkIndices:            []uint32{0},
			QuorumThresholdPercentages:  []uint32{50},
		},
	}, nil
}

// submitResponse submits a response to the contract
func (a *Aggregator) submitResponse(response *types.TaskResponseWithSignature, aggregatedSignature *types.AggregatedSignature) error {
	// Create task struct
	task := yieldsynctaskmanager.IYieldSyncTaskManagerTask{
		LstToken:                "stETH", // This would come from the actual task data
		TaskCreatedBlock:        uint32(time.Now().Unix()),
		QuorumNumbers:           []byte{0},
		QuorumThresholdPercentage: 50,
	}

	// Create task response struct
	taskResponse := yieldsynctaskmanager.IYieldSyncTaskManagerTaskResponse{
		ReferenceTaskIndex: response.TaskResponse.ReferenceTaskIndex,
		YieldRate:          response.TaskResponse.YieldRate,
		Timestamp:          uint32(response.TaskResponse.Timestamp.Unix()),
		DataHash:           response.TaskResponse.DataHash,
	}

	// Create non-signer stakes and signature struct
	nonSignerStakesAndSignature := yieldsynctaskmanager.IBLSSignatureCheckerNonSignerStakesAndSignature{
		NonSignerQuorumBitmapIndices: aggregatedSignature.NonSignerStakesAndSignature.NonSignerQuorumBitmapIndices,
		NonSignerPubkeys:            []yieldsynctaskmanager.BN254G1Point{},
		QuorumApks:                  []yieldsynctaskmanager.BN254G1Point{},
		ApkG2:                       yieldsynctaskmanager.BN254G2Point{},
		Sigma:                       yieldsynctaskmanager.BN254G1Point{},
		QuorumApkIndices:            aggregatedSignature.NonSignerStakesAndSignature.QuorumApkIndices,
		QuorumThresholdPercentages:  aggregatedSignature.NonSignerStakesAndSignature.QuorumThresholdPercentages,
	}

	// Submit response
	tx, err := a.yieldSyncContracts.TaskManager.RespondToTask(
		a.config.SignerFn,
		task,
		taskResponse,
		nonSignerStakesAndSignature,
	)
	if err != nil {
		return err
	}

	a.logger.Info("Response submitted", "txHash", tx.Hash().Hex())
	return nil
}

// createMessageHash creates a hash of the task response for signing
func (a *Aggregator) createMessageHash(taskResponse *types.TaskResponse) []byte {
	// This should match the hash function used in the smart contract
	data := fmt.Sprintf("%d:%d:%d:%s", 
		taskResponse.ReferenceTaskIndex,
		taskResponse.YieldRate,
		taskResponse.Timestamp.Unix(),
		taskResponse.DataHash,
	)
	hash := sha3.NewLegacyKeccak256()
	hash.Write([]byte(data))
	return hash.Sum(nil)
}

// verifySignature verifies a signature
func (a *Aggregator) verifySignature(messageHash []byte, signature []byte, operatorAddress string) bool {
	// This would implement signature verification
	// For now, return true
	return true
}
