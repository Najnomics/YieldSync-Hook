// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IYieldSyncAVS
 * @dev Interface for YieldSync EigenLayer AVS
 */
interface IYieldSyncAVS {
    /// @notice LST yield data structure
    struct LSTYieldData {
        address lstToken;                    // LST contract address
        uint256 currentYieldRate;           // Annual yield rate (basis points)
        uint256 lastUpdateTimestamp;        // When this was last updated
        uint256 validatorCount;             // Number of operators confirming
        bytes32 dataHash;                   // Hash for verification
    }

    /// @notice Yield adjustment task structure
    struct YieldAdjustmentTask {
        uint256 taskId;
        address lstToken;                    // Which LST needs adjustment calculation
        uint256 timePeriod;                  // Time period for adjustment calculation
        uint256 expectedAdjustmentBPS;       // Expected adjustment amount
        uint256 taskCreatedBlock;
        bool isCompleted;
    }

    /// @notice Events
    event YieldDataSubmitted(
        address indexed lstToken,
        uint256 yieldRate,
        address indexed operator,
        uint256 timestamp
    );
    
    event YieldAdjustmentCalculated(
        address indexed lstToken,
        uint256 timePeriod,
        uint256 adjustmentBPS,
        uint256 operatorCount
    );
    
    event OperatorRewardDistributed(
        address indexed operator,
        uint256 amount,
        string reason
    );

    /// @notice Functions
    function submitYieldData(
        address lstToken,
        uint256 yieldRate,
        bytes calldata yieldProof,
        bytes calldata signature
    ) external;
    
    function getRequiredAdjustment(
        address lstToken,
        uint256 lastAdjustmentTimestamp
    ) external view returns (uint256 adjustmentBPS);
    
    function lstYieldData(address lstToken) external view returns (LSTYieldData memory);
    function adjustmentTasks(uint256 taskId) external view returns (YieldAdjustmentTask memory);
    function operatorPerformanceScore(address operator) external view returns (uint256);
}
