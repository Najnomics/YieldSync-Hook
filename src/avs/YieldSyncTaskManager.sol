// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {Pausable as EigenLayerPausable} from "@eigenlayer/contracts/permissions/Pausable.sol";
import "@eigenlayer-middleware/interfaces/IServiceManager.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/BLSApkRegistry.sol";
import {SlashingRegistryCoordinator} from "@eigenlayer-middleware/SlashingRegistryCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {BLSSignatureChecker} from "@eigenlayer-middleware/BLSSignatureChecker.sol";
import {OperatorStateRetriever} from "@eigenlayer-middleware/OperatorStateRetriever.sol";
import {InstantSlasher} from "@eigenlayer-middleware/slashers/InstantSlasher.sol";
import "@eigenlayer-middleware/libraries/BN254.sol";
import "./IYieldSyncTaskManager.sol";
import {IAllocationManagerTypes} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IPauserRegistry} from "@eigenlayer/contracts/interfaces/IPauserRegistry.sol";
import {OperatorSet} from "@eigenlayer/contracts/libraries/OperatorSetLib.sol";

/**
 * @title YieldSyncTaskManager
 * @dev Task manager for yield monitoring and position adjustment tasks
 * @notice Manages LST yield data collection and consensus tasks
 */
contract YieldSyncTaskManager is
    Initializable,
    OwnableUpgradeable,
    EigenLayerPausable,
    BLSSignatureChecker,
    OperatorStateRetriever,
    IYieldSyncTaskManager
{
    using BN254 for BN254.G1Point;

    /* CONSTANT */
    // The number of blocks from the task initialization within which the aggregator has to respond to
    uint32 public immutable TASK_RESPONSE_WINDOW_BLOCK;
    uint32 public constant TASK_CHALLENGE_WINDOW_BLOCK = 100;
    uint256 internal constant _THRESHOLD_DENOMINATOR = 100;
    uint256 public constant WADS_TO_SLASH = 100_000_000_000_000_000; // 10%

    /* STORAGE */
    // The latest task index
    uint32 public latestTaskNum;

    // mapping of task indices to all tasks hashes
    mapping(uint32 => bytes32) public allTaskHashes;

    // mapping of task indices to hash of abi.encode(taskResponse, taskResponseMetadata)
    mapping(uint32 => bytes32) public allTaskResponses;

    mapping(uint32 => bool) public taskSuccessfullyChallenged;

    address public aggregator;
    address public generator;
    address public instantSlasher;
    address public allocationManager;
    address public serviceManager;

    /* MODIFIERS */
    modifier onlyAggregator() {
        require(msg.sender == aggregator, "Aggregator must be the caller");
        _;
    }

    modifier onlyTaskGenerator() {
        require(msg.sender == generator, "Task generator must be the caller");
        _;
    }

    constructor(
        ISlashingRegistryCoordinator _registryCoordinator,
        IPauserRegistry _pauserRegistry,
        uint32 _taskResponseWindowBlock
    ) BLSSignatureChecker(_registryCoordinator) EigenLayerPausable(_pauserRegistry) {
        TASK_RESPONSE_WINDOW_BLOCK = _taskResponseWindowBlock;
    }

    function initialize(
        address initialOwner,
        address _aggregator,
        address _generator,
        address _allocationManager,
        address _slasher,
        address _serviceManager
    ) public initializer {
        _transferOwnership(initialOwner);
        aggregator = _aggregator;
        generator = _generator;
        allocationManager = _allocationManager;
        instantSlasher = _slasher;
        serviceManager = _serviceManager;
    }

    /* FUNCTIONS */
    /**
     * @notice Create a new yield monitoring task
     * @param lstToken The LST token to monitor
     * @param quorumThresholdPercentage The threshold percentage for consensus
     * @param quorumNumbers The quorum numbers to use
     */
    function createNewTask(
        address lstToken,
        uint32 quorumThresholdPercentage,
        bytes calldata quorumNumbers
    ) external onlyTaskGenerator {
        // create a new task struct
        Task memory newTask;
        newTask.lstToken = lstToken;
        newTask.taskCreatedBlock = uint32(block.number);
        newTask.quorumThresholdPercentage = quorumThresholdPercentage;
        newTask.quorumNumbers = quorumNumbers;

        // store hash of task onchain, emit event, and increase taskNum
        allTaskHashes[latestTaskNum] = keccak256(abi.encode(newTask));
        emit NewTaskCreated(latestTaskNum, newTask);
        latestTaskNum = latestTaskNum + 1;
    }

    /**
     * @notice Respond to a yield monitoring task
     * @param task The task to respond to
     * @param taskResponse The task response
     * @param nonSignerStakesAndSignature The BLS signature data
     */
    function respondToTask(
        Task calldata task,
        TaskResponse calldata taskResponse,
        NonSignerStakesAndSignature memory nonSignerStakesAndSignature
    ) external onlyAggregator {
        uint32 taskCreatedBlock = task.taskCreatedBlock;
        bytes calldata quorumNumbers = task.quorumNumbers;
        uint32 quorumThresholdPercentage = task.quorumThresholdPercentage;

        // check that the task is valid, hasn't been responded yet, and is being responded in time
        require(
            keccak256(abi.encode(task)) == allTaskHashes[taskResponse.referenceTaskIndex],
            "supplied task does not match the one recorded in the contract"
        );
        require(
            allTaskResponses[taskResponse.referenceTaskIndex] == bytes32(0),
            "Aggregator has already responded to the task"
        );
        require(
            uint32(block.number) <= taskCreatedBlock + TASK_RESPONSE_WINDOW_BLOCK,
            "Aggregator has responded to the task too late"
        );

        /* CHECKING SIGNATURES & WHETHER THRESHOLD IS MET OR NOT */
        // calculate message which operators signed
        bytes32 message = keccak256(abi.encode(taskResponse));

        // check the BLS signature
        (QuorumStakeTotals memory quorumStakeTotals, bytes32 hashOfNonSigners) =
            checkSignatures(message, quorumNumbers, taskCreatedBlock, nonSignerStakesAndSignature);

        // check that signatories own at least a threshold percentage of each quorum
        for (uint256 i = 0; i < quorumNumbers.length; i++) {
            require(
                quorumStakeTotals.signedStakeForQuorum[i] * _THRESHOLD_DENOMINATOR
                    >= quorumStakeTotals.totalStakeForQuorum[i] * uint8(quorumThresholdPercentage),
                "Signatories do not own at least threshold percentage of a quorum"
            );
        }

        TaskResponseMetadata memory taskResponseMetadata =
            TaskResponseMetadata(uint32(block.number), hashOfNonSigners);
        
        // updating the storage with task response
        allTaskResponses[taskResponse.referenceTaskIndex] =
            keccak256(abi.encode(taskResponse, taskResponseMetadata));

        // emitting event
        emit TaskResponded(taskResponse, taskResponseMetadata);
    }

    function taskNumber() external view returns (uint32) {
        return latestTaskNum;
    }

    /**
     * @notice Raise and resolve a challenge to a task response
     * @param task The original task
     * @param taskResponse The task response being challenged
     * @param taskResponseMetadata The task response metadata
     * @param pubkeysOfNonSigningOperators The public keys of non-signing operators
     */
    function raiseAndResolveChallenge(
        Task calldata task,
        TaskResponse calldata taskResponse,
        TaskResponseMetadata calldata taskResponseMetadata,
        BN254.G1Point[] memory pubkeysOfNonSigningOperators
    ) external {
        uint32 referenceTaskIndex = taskResponse.referenceTaskIndex;
        address lstToken = task.lstToken;
        
        // some logical checks
        require(
            allTaskResponses[referenceTaskIndex] != bytes32(0), "Task hasn't been responded to yet"
        );
        require(
            allTaskResponses[referenceTaskIndex]
                == keccak256(abi.encode(taskResponse, taskResponseMetadata)),
            "Task response does not match the one recorded in the contract"
        );
        require(
            taskSuccessfullyChallenged[referenceTaskIndex] == false,
            "The response to this task has already been challenged successfully."
        );

        require(
            uint32(block.number)
                <= taskResponseMetadata.taskRespondedBlock + TASK_CHALLENGE_WINDOW_BLOCK,
            "The challenge period for this task has already expired."
        );

        // logic for checking whether challenge is valid or not
        // In a real implementation, this would verify the yield data against the LST protocol
        bool isResponseCorrect = _verifyYieldResponse(lstToken, taskResponse.yieldRate);
        
        // if response was correct, no slashing happens so we return
        if (isResponseCorrect == true) {
            emit TaskChallengedUnsuccessfully(referenceTaskIndex, msg.sender);
            return;
        }

        // get the list of hash of pubkeys of operators who weren't part of the task response submitted by the aggregator
        bytes32[] memory hashesOfPubkeysOfNonSigningOperators =
            new bytes32[](pubkeysOfNonSigningOperators.length);
        for (uint256 i = 0; i < pubkeysOfNonSigningOperators.length; i++) {
            hashesOfPubkeysOfNonSigningOperators[i] = pubkeysOfNonSigningOperators[i].hashG1Point();
        }

        // verify whether the pubkeys of "claimed" non-signers supplied by challenger are actually non-signers as recorded before
        bytes32 signatoryRecordHash =
            keccak256(abi.encodePacked(task.taskCreatedBlock, hashesOfPubkeysOfNonSigningOperators));
        require(
            signatoryRecordHash == taskResponseMetadata.hashOfNonSigners,
            "The pubkeys of non-signing operators supplied by the challenger are not correct."
        );

        // get the address of operators who didn't sign
        address[] memory addressOfNonSigningOperators =
            new address[](pubkeysOfNonSigningOperators.length);
        for (uint256 i = 0; i < pubkeysOfNonSigningOperators.length; i++) {
            addressOfNonSigningOperators[i] = BLSApkRegistry(address(blsApkRegistry))
                .pubkeyHashToOperator(hashesOfPubkeysOfNonSigningOperators[i]);
        }

        // get the list of all operators who were active when the task was initialized
        Operator[][] memory allOperatorInfo = getOperatorState(
            ISlashingRegistryCoordinator(address(registryCoordinator)),
            task.quorumNumbers,
            task.taskCreatedBlock
        );
        
        // first for loop iterate over quorums
        for (uint256 i = 0; i < allOperatorInfo.length; i++) {
            // second for loop iterate over operators active in the quorum when the task was initialized
            for (uint256 j = 0; j < allOperatorInfo[i].length; j++) {
                // get the operator address
                bytes32 operatorID = allOperatorInfo[i][j].operatorId;
                address operatorAddress = blsApkRegistry.getOperatorFromPubkeyHash(operatorID);
                // check whether the operator was a signer for the task
                bool wasSigningOperator = true;
                for (uint256 k = 0; k < addressOfNonSigningOperators.length; k++) {
                    if (operatorAddress == addressOfNonSigningOperators[k]) {
                        // if the operator was a non-signer, then we set the flag to false
                        wasSigningOperator = false;
                        break;
                    }
                }
                if (wasSigningOperator == true) {
                    OperatorSet memory operatorset =
                        OperatorSet({avs: serviceManager, id: uint8(task.quorumNumbers[i])});
                    IStrategy[] memory istrategy = IAllocationManager(allocationManager)
                        .getStrategiesInOperatorSet(operatorset);
                    uint256[] memory wadsToSlash = new uint256[](istrategy.length);
                    for (uint256 z = 0; z < wadsToSlash.length; z++) {
                        wadsToSlash[z] = WADS_TO_SLASH;
                    }
                    IAllocationManagerTypes.SlashingParams memory slashingparams =
                    IAllocationManagerTypes.SlashingParams({
                        operator: operatorAddress,
                        operatorSetId: uint8(task.quorumNumbers[i]),
                        strategies: istrategy,
                        wadsToSlash: wadsToSlash,
                        description: "slash_the_operator"
                    });
                    InstantSlasher(instantSlasher).fulfillSlashingRequest(slashingparams);
                }
            }
        }

        // the task response has been challenged successfully
        taskSuccessfullyChallenged[referenceTaskIndex] = true;

        emit TaskChallengedSuccessfully(referenceTaskIndex, msg.sender);
    }

    function getTaskResponseWindowBlock() external view returns (uint32) {
        return TASK_RESPONSE_WINDOW_BLOCK;
    }

    /**
     * @notice Verify yield response (placeholder implementation)
     * @param lstToken The LST token address
     * @param yieldRate The reported yield rate
     * @return isValid Whether the yield response is valid
     */
    function _verifyYieldResponse(address lstToken, uint256 yieldRate) internal pure returns (bool isValid) {
        // Placeholder implementation
        // In production, this would verify against the actual LST protocol data
        // For now, just check reasonable bounds
        return yieldRate > 0 && yieldRate <= 10000; // 0-100% annual yield
    }
}
