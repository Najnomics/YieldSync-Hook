// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";
import {YieldCalculations} from "./YieldCalculations.sol";

/**
 * @title PositionAdjustment
 * @dev Library for LP position adjustment calculations
 */
library PositionAdjustment {
    /// @notice Position data structure
    struct PositionData {
        address owner;
        PoolId poolId;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        address lstToken;                    // Which LST is in this position
        uint256 lastYieldAdjustment;         // Timestamp of last adjustment
        uint256 accumulatedYieldBPS;         // Total yield accumulated
        bool autoAdjustEnabled;              // Whether auto-adjustment is enabled
    }

    /// @notice Calculate adjusted tick range based on yield accumulation
    /// @param currentTickLower Current lower tick
    /// @param currentTickUpper Current upper tick
    /// @param yieldBPS Yield in basis points
    /// @param isLSTToken0 Whether LST is token0
    /// @return newTickLower New lower tick
    /// @return newTickUpper New upper tick
    function calculateAdjustedTicks(
        int24 currentTickLower,
        int24 currentTickUpper,
        uint256 yieldBPS,
        bool isLSTToken0
    ) internal pure returns (int24 newTickLower, int24 newTickUpper) {
        // Convert yield BPS to tick adjustment
        // LSTs appreciate relative to their pairs, so shift the range
        int24 tickShift = int24(int256(yieldBPS * 4)); // Simplified conversion
        
        if (isLSTToken0) {
            // LST is token0, appreciating means shifting range up
            newTickLower = currentTickLower + tickShift;
            newTickUpper = currentTickUpper + tickShift;
        } else {
            // LST is token1, appreciating means shifting range down  
            newTickLower = currentTickLower - tickShift;
            newTickUpper = currentTickUpper - tickShift;
        }
        
        return (newTickLower, newTickUpper);
    }

    /// @notice Calculate position efficiency after adjustment
    /// @param position The position data
    /// @param yieldBPS The yield in basis points
    /// @return efficiency The position efficiency (0-10000, where 10000 = 100%)
    function calculatePositionEfficiency(
        PositionData memory position,
        uint256 yieldBPS
    ) internal pure returns (uint256 efficiency) {
        // Calculate how much the position has drifted from optimal
        uint256 driftBPS = yieldBPS;
        
        // Efficiency decreases as drift increases
        // At 0% drift: 100% efficiency
        // At 1% drift: ~95% efficiency
        // At 5% drift: ~75% efficiency
        if (driftBPS >= 10000) {
            efficiency = 0; // 100%+ drift = 0% efficiency
        } else {
            efficiency = 10000 - (driftBPS * 5); // 5x penalty for drift
            if (efficiency < 0) efficiency = 0;
        }
        
        return efficiency;
    }

    /// @notice Check if position needs adjustment
    /// @param position The position data
    /// @param currentYieldBPS Current yield in basis points
    /// @param thresholdBPS Adjustment threshold in basis points
    /// @param cooldownPeriod Cooldown period in seconds
    /// @return needsAdjustment Whether position needs adjustment
    function needsAdjustment(
        PositionData memory position,
        uint256 currentYieldBPS,
        uint256 thresholdBPS,
        uint256 cooldownPeriod
    ) internal view returns (bool needsAdjustment) {
        // Check if yield exceeds threshold
        if (currentYieldBPS < thresholdBPS) {
            return false;
        }
        
        // Check if cooldown period has passed
        if (block.timestamp < position.lastYieldAdjustment + cooldownPeriod) {
            return false;
        }
        
        // Check if auto-adjustment is enabled
        if (!position.autoAdjustEnabled) {
            return false;
        }
        
        return true;
    }

    /// @notice Calculate optimal position range based on expected yield
    /// @param currentTickLower Current lower tick
    /// @param currentTickUpper Current upper tick
    /// @param expectedYieldBPS Expected yield in basis points
    /// @param isLSTToken0 Whether LST is token0
    /// @return optimalTickLower Optimal lower tick
    /// @return optimalTickUpper Optimal upper tick
    function calculateOptimalRange(
        int24 currentTickLower,
        int24 currentTickUpper,
        uint256 expectedYieldBPS,
        bool isLSTToken0
    ) internal pure returns (int24 optimalTickLower, int24 optimalTickUpper) {
        // Calculate the center of the current range
        int24 currentCenter = (currentTickLower + currentTickUpper) / 2;
        
        // Calculate optimal center based on expected yield
        int24 optimalCenter = YieldCalculations.calculateOptimalTick(
            currentCenter,
            expectedYieldBPS,
            isLSTToken0
        );
        
        // Calculate range width
        int24 rangeWidth = currentTickUpper - currentTickLower;
        
        // Set new range around optimal center
        optimalTickLower = optimalCenter - (rangeWidth / 2);
        optimalTickUpper = optimalCenter + (rangeWidth / 2);
        
        return (optimalTickLower, optimalTickUpper);
    }

    /// @notice Validate tick range
    /// @param tickLower Lower tick
    /// @param tickUpper Upper tick
    /// @return isValid Whether the tick range is valid
    function validateTickRange(
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bool isValid) {
        // Check basic validity
        if (tickLower >= tickUpper) {
            return false;
        }
        
        // Check reasonable bounds (adjust as needed)
        if (tickLower < -887272 || tickUpper > 887272) {
            return false;
        }
        
        return true;
    }
}
