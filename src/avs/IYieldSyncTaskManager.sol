// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@eigenlayer-middleware/libraries/BN254.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";

/**
 * @title IYieldSyncTaskManager
 * @dev Interface for YieldSync Task Manager
 */
interface IYieldSyncTaskManager {
    // EVENTS
    event NewTaskCreated(uint32 indexed taskIndex, Task task);
    event TaskResponded(TaskResponse taskResponse, TaskResponseMetadata taskResponseMetadata);
    event TaskCompleted(uint32 indexed taskIndex);
    event TaskChallengedSuccessfully(uint32 indexed taskIndex, address indexed challenger);
    event TaskChallengedUnsuccessfully(uint32 indexed taskIndex, address indexed challenger);

    // STRUCTS
    struct Task {
        address lstToken;                    // LST token to monitor
        uint32 taskCreatedBlock;             // Block when task was created
        bytes quorumNumbers;                 // Quorum numbers for consensus
        uint32 quorumThresholdPercentage;    // Threshold percentage for consensus
    }

    struct TaskResponse {
        uint32 referenceTaskIndex;           // Reference to the original task
        uint256 yieldRate;                   // Reported yield rate in basis points
        uint256 timestamp;                   // Timestamp of the response
        bytes32 dataHash;                    // Hash of the yield data
    }

    struct TaskResponseMetadata {
        uint32 taskRespondedBlock;           // Block when task was responded to
        bytes32 hashOfNonSigners;            // Hash of non-signing operators
    }

    // FUNCTIONS
    function createNewTask(
        address lstToken,
        uint32 quorumThresholdPercentage,
        bytes calldata quorumNumbers
    ) external;

    function taskNumber() external view returns (uint32);
    
    function raiseAndResolveChallenge(
        Task calldata task,
        TaskResponse calldata taskResponse,
        TaskResponseMetadata calldata taskResponseMetadata,
        BN254.G1Point[] memory pubkeysOfNonSigningOperators
    ) external;

    function getTaskResponseWindowBlock() external view returns (uint32);
}
