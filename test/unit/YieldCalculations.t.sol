// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/hooks/libraries/YieldCalculations.sol";

contract YieldCalculationsUnitTest is Test {
    
    // Test constants
    int24 constant VALID_TICK = 1000;
    int24 constant NEGATIVE_TICK = -1000;
    uint256 constant VALID_YIELD_BPS = 500; // 5%
    uint256 constant HIGH_YIELD_BPS = 2000; // 20%
    uint256 constant LOW_YIELD_BPS = 50; // 0.5%
    uint128 constant VALID_LIQUIDITY = 1e18;
    address constant LST_TOKEN = 0xae78736Cd615f374D3085123A210448E74Fc6393; // rETH

    function createYieldData() internal pure returns (YieldCalculations.YieldData memory) {
        return YieldCalculations.YieldData({
            annualYieldRate: 500, // 5% annual
            timeElapsed: 86400, // 1 day in seconds
            liquidity: 1e18
        });
    }

    // Calculate Optimal Tick Tests (10 tests)
    function test_CalculateOptimalTick_BasicCalculation() public {
        int24 result = YieldCalculations.calculateOptimalTick(VALID_TICK, VALID_YIELD_BPS, true);
        assertNotEq(result, VALID_TICK);
    }

    function test_CalculateOptimalTick_NegativeTick() public {
        int24 result = YieldCalculations.calculateOptimalTick(NEGATIVE_TICK, VALID_YIELD_BPS, true);
        assertGt(result, NEGATIVE_TICK); // Should shift up for LST as token0
    }

    function test_CalculateOptimalTick_ZeroTick() public {
        int24 result = YieldCalculations.calculateOptimalTick(0, VALID_YIELD_BPS, true);
        assertGt(result, 0); // Should shift up for LST as token0
    }

    function test_CalculateOptimalTick_ZeroYield() public {
        int24 result = YieldCalculations.calculateOptimalTick(VALID_TICK, 0, true);
        assertEq(result, VALID_TICK); // No shift for zero yield
    }

    function test_CalculateOptimalTick_HighYield() public {
        int24 result = YieldCalculations.calculateOptimalTick(VALID_TICK, HIGH_YIELD_BPS, true);
        assertGt(result, VALID_TICK + int24(int256(VALID_YIELD_BPS * 4))); // Should shift more than basic yield
    }

    function test_CalculateOptimalTick_LowYield() public {
        int24 result = YieldCalculations.calculateOptimalTick(VALID_TICK, LOW_YIELD_BPS, true);
        assertLt(result, VALID_TICK + int24(int256(VALID_YIELD_BPS * 4))); // Should shift less than basic yield
    }

    function test_CalculateOptimalTick_MaxBounds() public {
        int24 maxTick = 887272;
        int24 result = YieldCalculations.calculateOptimalTick(maxTick, VALID_YIELD_BPS, true);
        // Should handle max bounds gracefully
        assertNotEq(result, 0);
    }

    function test_CalculateOptimalTick_MinBounds() public {
        int24 minTick = -887272;
        int24 result = YieldCalculations.calculateOptimalTick(minTick, VALID_YIELD_BPS, true);
        // Should handle min bounds gracefully
        assertNotEq(result, 0);
    }

    function test_CalculateOptimalTick_LargeYield() public {
        uint256 largeYield = 10000; // 100%
        int24 result = YieldCalculations.calculateOptimalTick(VALID_TICK, largeYield, true);
        assertGt(result, VALID_TICK);
    }

    function test_CalculateOptimalTick_Consistency() public {
        int24 result1 = YieldCalculations.calculateOptimalTick(VALID_TICK, VALID_YIELD_BPS, true);
        int24 result2 = YieldCalculations.calculateOptimalTick(VALID_TICK, VALID_YIELD_BPS, true);
        assertEq(result1, result2); // Should be deterministic
    }

    // LST Token Direction Tests (5 tests)
    function test_CalculateOptimalTick_LSTToken0() public {
        int24 result = YieldCalculations.calculateOptimalTick(0, VALID_YIELD_BPS, true);
        assertGt(result, 0); // LST as token0 should shift up
    }

    function test_CalculateOptimalTick_LSTToken1() public {
        int24 result = YieldCalculations.calculateOptimalTick(0, VALID_YIELD_BPS, false);
        assertLt(result, 0); // LST as token1 should shift down
    }

    function test_CalculateOptimalTick_DirectionDifference() public {
        int24 baseTick = 1000;
        int24 result0 = YieldCalculations.calculateOptimalTick(baseTick, 400, true);
        int24 result1 = YieldCalculations.calculateOptimalTick(baseTick, 400, false);
        
        // Results should be on opposite sides of base tick
        assertGt(result0, baseTick);
        assertLt(result1, baseTick);
    }

    function test_CalculateOptimalTick_SymmetricShift() public {
        int24 baseTick = 0;
        int24 result0 = YieldCalculations.calculateOptimalTick(baseTick, 500, true);
        int24 result1 = YieldCalculations.calculateOptimalTick(baseTick, 500, false);
        
        // Should be symmetric around base tick
        assertEq(result0, -result1);
    }

    function test_CalculateOptimalTick_MagnitudeConsistency() public {
        int24 baseTick = 1000;
        int24 result0 = YieldCalculations.calculateOptimalTick(baseTick, 500, true);
        int24 result1 = YieldCalculations.calculateOptimalTick(baseTick, 500, false);
        
        // Magnitude of shift should be same, just direction different
        int24 shift0 = result0 - baseTick;
        int24 shift1 = baseTick - result1;
        assertEq(shift0, shift1);
    }

    // Calculate IL Prevented Tests (10 tests)
    function test_CalculateILPrevented_BasicCalculation() public {
        uint256 result = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, VALID_YIELD_BPS);
        assertGt(result, 0);
    }

    function test_CalculateILPrevented_ZeroLiquidity() public {
        uint256 result = YieldCalculations.calculateILPrevented(0, VALID_YIELD_BPS);
        assertEq(result, 0);
    }

    function test_CalculateILPrevented_ZeroYield() public {
        uint256 result = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, 0);
        assertEq(result, 0);
    }

    function test_CalculateILPrevented_HighLiquidity() public {
        uint128 highLiquidity = 1e20;
        uint256 normalResult = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, VALID_YIELD_BPS);
        uint256 highResult = YieldCalculations.calculateILPrevented(highLiquidity, VALID_YIELD_BPS);
        assertGt(highResult, normalResult);
    }

    function test_CalculateILPrevented_HighYield() public {
        uint256 normalResult = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, VALID_YIELD_BPS);
        uint256 highResult = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, HIGH_YIELD_BPS);
        assertGt(highResult, normalResult);
    }

    function test_CalculateILPrevented_LowYield() public {
        uint256 normalResult = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, VALID_YIELD_BPS);
        uint256 lowResult = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, LOW_YIELD_BPS);
        assertLt(lowResult, normalResult);
    }

    function test_CalculateILPrevented_LinearLiquidityScaling() public {
        uint256 result1 = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, VALID_YIELD_BPS);
        uint256 result2 = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY * 2, VALID_YIELD_BPS);
        
        // Should scale roughly linearly with liquidity
        assertGt(result2, result1);
        assertLt(result2, result1 * 3); // Not exactly 2x due to quadratic component
    }

    function test_CalculateILPrevented_QuadraticYieldScaling() public {
        uint256 result1 = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, 100);
        uint256 result2 = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, 200);
        uint256 result3 = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, 400);
        
        // Should scale quadratically with yield (roughly 4x when yield doubles)
        assertGt(result2, result1);
        assertGt(result3, result2 * 3); // Should be significantly more
    }

    function test_CalculateILPrevented_ReasonableBounds() public {
        uint256 result = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, VALID_YIELD_BPS);
        
        // Should be reasonable fraction of liquidity
        assertLt(result, uint256(VALID_LIQUIDITY) / 100); // Less than 1% of liquidity
    }

    function test_CalculateILPrevented_Consistency() public {
        uint256 result1 = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, VALID_YIELD_BPS);
        uint256 result2 = YieldCalculations.calculateILPrevented(VALID_LIQUIDITY, VALID_YIELD_BPS);
        assertEq(result1, result2);
    }

    // Calculate Daily Yield Rate Tests (10 tests)
    function test_CalculateDailyYieldRate_BasicCalculation() public {
        uint256 annualRate = 365 * 10; // Should give daily rate of 10
        uint256 dailyRate = YieldCalculations.calculateDailyYieldRate(annualRate);
        assertEq(dailyRate, 10);
    }

    function test_CalculateDailyYieldRate_ZeroAnnual() public {
        uint256 dailyRate = YieldCalculations.calculateDailyYieldRate(0);
        assertEq(dailyRate, 0);
    }

    function test_CalculateDailyYieldRate_TypicalLSTYield() public {
        uint256 annualRate = 500; // 5%
        uint256 dailyRate = YieldCalculations.calculateDailyYieldRate(annualRate);
        assertEq(dailyRate, 1); // 500/365 = 1.37, rounds down to 1
    }

    function test_CalculateDailyYieldRate_HighYield() public {
        uint256 annualRate = 3650; // 36.5%
        uint256 dailyRate = YieldCalculations.calculateDailyYieldRate(annualRate);
        assertEq(dailyRate, 10);
    }

    function test_CalculateDailyYieldRate_LowYield() public {
        uint256 annualRate = 100; // 1%
        uint256 dailyRate = YieldCalculations.calculateDailyYieldRate(annualRate);
        assertEq(dailyRate, 0); // 100/365 = 0.27, rounds down to 0
    }

    function test_CalculateDailyYieldRate_PrecisionLoss() public {
        uint256 annualRate = 364; // Just under 1 BPS per day
        uint256 dailyRate = YieldCalculations.calculateDailyYieldRate(annualRate);
        assertEq(dailyRate, 0); // Should round down
    }

    function test_CalculateDailyYieldRate_ExactDivision() public {
        uint256 annualRate = 730; // Exactly 2 BPS per day
        uint256 dailyRate = YieldCalculations.calculateDailyYieldRate(annualRate);
        assertEq(dailyRate, 2);
    }

    function test_CalculateDailyYieldRate_LargeValue() public {
        uint256 annualRate = 365000; // 3650%
        uint256 dailyRate = YieldCalculations.calculateDailyYieldRate(annualRate);
        assertEq(dailyRate, 1000);
    }

    function test_CalculateDailyYieldRate_Overflow() public {
        uint256 maxAnnual = type(uint256).max / 365;
        uint256 dailyRate = YieldCalculations.calculateDailyYieldRate(maxAnnual);
        assertGt(dailyRate, 0); // Should not overflow
    }

    function test_CalculateDailyYieldRate_Consistency() public {
        uint256 annualRate = 1825; // 18.25%
        uint256 dailyRate1 = YieldCalculations.calculateDailyYieldRate(annualRate);
        uint256 dailyRate2 = YieldCalculations.calculateDailyYieldRate(annualRate);
        assertEq(dailyRate1, dailyRate2);
    }

    // Calculate Accumulated Yield Tests (10 tests)
    function test_CalculateAccumulatedYield_OneDayExact() public {
        uint256 annualRate = 365; // 3.65%
        uint256 timeElapsed = 86400; // 1 day
        uint256 result = YieldCalculations.calculateAccumulatedYield(annualRate, timeElapsed);
        assertEq(result, 1); // Should be 1 BPS for 1 day
    }

    function test_CalculateAccumulatedYield_ZeroTime() public {
        uint256 result = YieldCalculations.calculateAccumulatedYield(VALID_YIELD_BPS, 0);
        assertEq(result, 0);
    }

    function test_CalculateAccumulatedYield_ZeroAnnualRate() public {
        uint256 result = YieldCalculations.calculateAccumulatedYield(0, 86400);
        assertEq(result, 0);
    }

    function test_CalculateAccumulatedYield_OneHour() public {
        uint256 annualRate = 8760; // 87.6% annual (1% per hour)
        uint256 timeElapsed = 3600; // 1 hour
        uint256 result = YieldCalculations.calculateAccumulatedYield(annualRate, timeElapsed);
        assertEq(result, 1); // Should be 1 BPS for 1 hour
    }

    function test_CalculateAccumulatedYield_OneWeek() public {
        uint256 annualRate = 520; // 5.2% annual
        uint256 timeElapsed = 604800; // 1 week
        uint256 result = YieldCalculations.calculateAccumulatedYield(annualRate, timeElapsed);
        assertEq(result, 10); // Should be 10 BPS for 1 week
    }

    function test_CalculateAccumulatedYield_LongPeriod() public {
        uint256 annualRate = 1000; // 10%
        uint256 timeElapsed = 31536000; // 1 year
        uint256 result = YieldCalculations.calculateAccumulatedYield(annualRate, timeElapsed);
        assertEq(result, 1000); // Should equal annual rate
    }

    function test_CalculateAccumulatedYield_ShortPeriod() public {
        uint256 annualRate = 31536000; // Very high rate for testing
        uint256 timeElapsed = 1; // 1 second
        uint256 result = YieldCalculations.calculateAccumulatedYield(annualRate, timeElapsed);
        assertEq(result, 1); // Should be 1 BPS for 1 second
    }

    function test_CalculateAccumulatedYield_FractionalDay() public {
        uint256 annualRate = 730; // 7.3%
        uint256 timeElapsed = 43200; // 12 hours
        uint256 result = YieldCalculations.calculateAccumulatedYield(annualRate, timeElapsed);
        assertEq(result, 1); // Should be 1 BPS for 12 hours
    }

    function test_CalculateAccumulatedYield_LinearScaling() public {
        uint256 annualRate = 1000;
        uint256 result1 = YieldCalculations.calculateAccumulatedYield(annualRate, 86400);
        uint256 result2 = YieldCalculations.calculateAccumulatedYield(annualRate, 172800);
        
        // Double time should roughly double result
        assertGt(result2, result1);
        assertLe(result2, result1 * 3); // Should be close to 2x
    }

    function test_CalculateAccumulatedYield_Consistency() public {
        uint256 result1 = YieldCalculations.calculateAccumulatedYield(500, 86400);
        uint256 result2 = YieldCalculations.calculateAccumulatedYield(500, 86400);
        assertEq(result1, result2);
    }

    // Validate Yield Data Tests (10 tests)
    function test_ValidateYieldData_ValidInput() public {
        bool isValid = YieldCalculations.validateYieldData(VALID_YIELD_BPS, LST_TOKEN);
        assertTrue(isValid);
    }

    function test_ValidateYieldData_ZeroYield() public {
        bool isValid = YieldCalculations.validateYieldData(0, LST_TOKEN);
        assertFalse(isValid);
    }

    function test_ValidateYieldData_MaxValidYield() public {
        bool isValid = YieldCalculations.validateYieldData(50000, LST_TOKEN); // 500%
        assertTrue(isValid);
    }

    function test_ValidateYieldData_ExcessiveYield() public {
        bool isValid = YieldCalculations.validateYieldData(50001, LST_TOKEN); // > 500%
        assertFalse(isValid);
    }

    function test_ValidateYieldData_TypicalLSTYield() public {
        bool isValid = YieldCalculations.validateYieldData(400, LST_TOKEN); // 4%
        assertTrue(isValid);
    }

    function test_ValidateYieldData_HighButValidYield() public {
        bool isValid = YieldCalculations.validateYieldData(20000, LST_TOKEN); // 200%
        assertTrue(isValid);
    }

    function test_ValidateYieldData_LowValidYield() public {
        bool isValid = YieldCalculations.validateYieldData(1, LST_TOKEN); // 0.01%
        assertTrue(isValid);
    }

    function test_ValidateYieldData_ZeroAddress() public {
        bool isValid = YieldCalculations.validateYieldData(VALID_YIELD_BPS, address(0));
        assertTrue(isValid); // Currently doesn't validate address
    }

    function test_ValidateYieldData_VeryHighYield() public {
        bool isValid = YieldCalculations.validateYieldData(49999, LST_TOKEN);
        assertTrue(isValid);
    }

    function test_ValidateYieldData_Consistency() public {
        bool result1 = YieldCalculations.validateYieldData(VALID_YIELD_BPS, LST_TOKEN);
        bool result2 = YieldCalculations.validateYieldData(VALID_YIELD_BPS, LST_TOKEN);
        assertEq(result1, result2);
    }
}