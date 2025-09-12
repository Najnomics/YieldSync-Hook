// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title YieldCalculations
 * @dev Library for LST yield calculations and IL prevention estimates
 */
library YieldCalculations {
    /// @notice Yield data structure
    struct YieldData {
        uint256 annualYieldRate;     // Annual yield rate in basis points
        uint256 timeElapsed;         // Time elapsed since last adjustment
        uint256 liquidity;           // Position liquidity
    }

    /// @notice Calculate impermanent loss prevented by position adjustment
    /// @param liquidity The position liquidity
    /// @param yieldBPS The yield in basis points
    /// @return ilPrevented The estimated IL prevented
    function calculateILPrevented(
        uint128 liquidity,
        uint256 yieldBPS
    ) internal pure returns (uint256 ilPrevented) {
        // Simplified IL prevention calculation
        // Real implementation would use sophisticated mathematical models
        uint256 estimatedIL = (uint256(liquidity) * yieldBPS * yieldBPS) / (10000 * 10000);
        ilPrevented = estimatedIL * 75 / 100; // Assume 75% IL prevention
        return ilPrevented;
    }

    /// @notice Calculate daily yield rate from annual rate
    /// @param annualYieldBPS Annual yield rate in basis points
    /// @return dailyYieldBPS Daily yield rate in basis points
    function calculateDailyYieldRate(uint256 annualYieldBPS) internal pure returns (uint256 dailyYieldBPS) {
        // Convert annual to daily: daily = annual / 365
        dailyYieldBPS = annualYieldBPS / 365;
        return dailyYieldBPS;
    }

    /// @notice Calculate yield accumulation over time period
    /// @param annualYieldBPS Annual yield rate in basis points
    /// @param timeElapsed Time elapsed in seconds
    /// @return accumulatedYieldBPS Accumulated yield in basis points
    function calculateAccumulatedYield(
        uint256 annualYieldBPS,
        uint256 timeElapsed
    ) internal pure returns (uint256 accumulatedYieldBPS) {
        // Calculate yield per second: annual / (365 * 24 * 3600)
        uint256 yieldPerSecond = annualYieldBPS / (365 * 24 * 3600);
        accumulatedYieldBPS = yieldPerSecond * timeElapsed;
        return accumulatedYieldBPS;
    }

    /// @notice Calculate optimal tick adjustment based on yield
    /// @param currentTick Current tick position
    /// @param yieldBPS Yield in basis points
    /// @param isLSTToken0 Whether LST is token0
    /// @return newTick New tick position
    function calculateOptimalTick(
        int24 currentTick,
        uint256 yieldBPS,
        bool isLSTToken0
    ) internal pure returns (int24 newTick) {
        // Convert yield BPS to tick adjustment
        // LSTs appreciate relative to their pairs, so shift the range
        int24 tickShift = int24(int256(yieldBPS * 4)); // Simplified conversion
        
        if (isLSTToken0) {
            // LST is token0, appreciating means shifting range up
            newTick = currentTick + tickShift;
        } else {
            // LST is token1, appreciating means shifting range down  
            newTick = currentTick - tickShift;
        }
        
        return newTick;
    }

    /// @notice Validate yield data for reasonableness
    /// @param yieldBPS Yield in basis points
    /// @param lstToken LST token address
    /// @return isValid Whether the yield data is valid
    function validateYieldData(
        uint256 yieldBPS,
        address lstToken
    ) internal pure returns (bool isValid) {
        // Basic sanity checks
        if (yieldBPS == 0 || yieldBPS > 50000) { // Max 500% annual yield
            return false;
        }
        
        // Token-specific validation could be added here
        // For now, just check basic bounds
        return true;
    }
}
