// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";
import {PositionAdjustment} from "../libraries/PositionAdjustment.sol";

/**
 * @title IYieldSyncHook
 * @dev Interface for YieldSync Hook contract
 */
interface IYieldSyncHook {
    /// @notice LST configuration for a pool
    struct LSTConfig {
        address lstToken;                    // LST in this pool (stETH, rETH, etc.)
        address pairedToken;                 // Paired token (ETH, USDC, etc.)
        bool isLSTToken0;                    // True if LST is token0
        uint256 adjustmentThresholdBPS;      // Minimum yield to trigger adjustment (50 = 0.5%)
        bool autoAdjustmentEnabled;          // Pool-level auto-adjustment setting
    }


    /// @notice Events
    event PositionRegistered(
        bytes32 indexed positionId,
        address indexed owner,
        address indexed lstToken,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    );
    
    event PositionAdjusted(
        bytes32 indexed positionId,
        address indexed owner,
        int24 oldTickLower,
        int24 oldTickUpper,
        int24 newTickLower,
        int24 newTickUpper,
        uint256 yieldBPS,
        uint256 estimatedILPrevented
    );
    
    event PoolConfigured(
        PoolId indexed poolId,
        address indexed lstToken,
        address indexed pairedToken,
        bool autoAdjustmentEnabled
    );

    /// @notice Functions
    function positions(bytes32 positionId) external view returns (PositionAdjustment.PositionData memory);
    function poolConfigs(PoolId poolId) external view returns (LSTConfig memory);
    function totalILPrevented(address user) external view returns (uint256);
    function manuallyAdjustPosition(bytes32 positionId) external;
    function setAutoAdjustment(bytes32 positionId, bool enabled) external;
    function getPositionHealth(bytes32 positionId) external view returns (
        uint256 currentYieldDrift,
        bool needsAdjustment,
        uint256 potentialILPrevention,
        uint256 timeSinceLastAdjustment
    );
    function configurePool(PoolId poolId, LSTConfig calldata config) external;
}
