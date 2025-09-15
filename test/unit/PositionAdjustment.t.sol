// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/hooks/libraries/PositionAdjustment.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";

contract PositionAdjustmentUnitTest is Test {
    using PositionAdjustment for PositionAdjustment.PositionData;
    using CurrencyLibrary for Currency;

    // Test data structures
    PositionAdjustment.PositionData positionData;
    PoolKey poolKey;
    
    // Test constants
    address constant TOKEN0 = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
    address constant TOKEN1 = 0xae78736Cd615f374D3085123A210448E74Fc6393; // rETH
    int24 constant TICK_SPACING = 60;
    uint24 constant FEE = 3000;
    uint160 constant SQRT_PRICE = 1771845812700903892492222464; // Approximately 1.25 price

    function setUp() public {
        // Initialize pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(TOKEN0),
            currency1: Currency.wrap(TOKEN1),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });

        // Initialize position data
        positionData = PositionAdjustment.PositionData({
            owner: address(this),
            poolId: PoolId.wrap(keccak256(abi.encode(poolKey))),
            tickLower: -600,
            tickUpper: 600,
            liquidity: 1000000000000000000, // 1e18
            lstToken: TOKEN1, // rETH is the LST
            lastYieldAdjustment: block.timestamp - 1 days,
            accumulatedYieldBPS: 400, // 4%
            autoAdjustEnabled: true
        });
    }

    // Tick Range Validation Tests (10 tests)
    function test_ValidateTickRange_ValidRange() public {
        bool isValid = PositionAdjustment.validateTickRange(-600, 600);
        assertTrue(isValid);
    }

    function test_ValidateTickRange_InvalidRange() public {
        bool isValid = PositionAdjustment.validateTickRange(600, -600);
        assertFalse(isValid);
    }

    function test_ValidateTickRange_EqualTicks() public {
        bool isValid = PositionAdjustment.validateTickRange(0, 0);
        assertFalse(isValid);
    }

    function test_ValidateTickRange_MaxBounds() public {
        bool isValid = PositionAdjustment.validateTickRange(-887272, 887272);
        assertTrue(isValid);
    }

    function test_ValidateTickRange_ExceedsLowerBound() public {
        bool isValid = PositionAdjustment.validateTickRange(-887273, 0);
        assertFalse(isValid);
    }

    function test_ValidateTickRange_ExceedsUpperBound() public {
        bool isValid = PositionAdjustment.validateTickRange(0, 887273);
        assertFalse(isValid);
    }

    function test_ValidateTickRange_SmallValidRange() public {
        bool isValid = PositionAdjustment.validateTickRange(-60, 60);
        assertTrue(isValid);
    }

    function test_ValidateTickRange_LargeValidRange() public {
        bool isValid = PositionAdjustment.validateTickRange(-100000, 100000);
        assertTrue(isValid);
    }

    function test_ValidateTickRange_NegativeRange() public {
        bool isValid = PositionAdjustment.validateTickRange(-1000, -500);
        assertTrue(isValid);
    }

    function test_ValidateTickRange_PositiveRange() public {
        bool isValid = PositionAdjustment.validateTickRange(500, 1000);
        assertTrue(isValid);
    }

    // Calculate Adjusted Ticks Tests (10 tests)
    function test_CalculateAdjustedTicks_LSTToken0_PositiveYield() public {
        (int24 newLower, int24 newUpper) = PositionAdjustment.calculateAdjustedTicks(
            -600, 600, 500, true // 5% yield, LST is token0
        );
        
        // LST appreciating as token0 should shift range up
        assertGt(newLower, -600);
        assertGt(newUpper, 600);
    }

    function test_CalculateAdjustedTicks_LSTToken1_PositiveYield() public {
        (int24 newLower, int24 newUpper) = PositionAdjustment.calculateAdjustedTicks(
            -600, 600, 500, false // 5% yield, LST is token1
        );
        
        // LST appreciating as token1 should shift range down
        assertLt(newLower, -600);
        assertLt(newUpper, 600);
    }

    function test_CalculateAdjustedTicks_ZeroYield() public {
        (int24 newLower, int24 newUpper) = PositionAdjustment.calculateAdjustedTicks(
            -600, 600, 0, true
        );
        
        // Zero yield should maintain same range
        assertEq(newLower, -600);
        assertEq(newUpper, 600);
    }

    function test_CalculateAdjustedTicks_HighYield() public {
        (int24 newLower, int24 newUpper) = PositionAdjustment.calculateAdjustedTicks(
            -600, 600, 2000, true // 20% yield
        );
        
        // High yield should cause significant shift
        assertGt(newUpper - newLower, 1200); // Range should maintain width
        assertGt(newLower, -600);
    }

    function test_CalculateAdjustedTicks_SmallYield() public {
        (int24 newLower, int24 newUpper) = PositionAdjustment.calculateAdjustedTicks(
            -600, 600, 50, true // 0.5% yield
        );
        
        // Small yield should cause small shift
        assertGt(newLower, -600);
        assertLt(newLower, -400); // Should be modest shift
    }

    function test_CalculateAdjustedTicks_RangeWidthPreserved() public {
        int24 originalWidth = 600 - (-600);
        
        (int24 newLower, int24 newUpper) = PositionAdjustment.calculateAdjustedTicks(
            -600, 600, 500, true
        );
        
        int24 newWidth = newUpper - newLower;
        assertEq(newWidth, originalWidth);
    }

    function test_CalculateAdjustedTicks_AsymmetricRange() public {
        (int24 newLower, int24 newUpper) = PositionAdjustment.calculateAdjustedTicks(
            -1200, 300, 500, true
        );
        
        // Range width should be preserved
        assertEq(newUpper - newLower, 300 - (-1200));
    }

    function test_CalculateAdjustedTicks_NegativeRange() public {
        (int24 newLower, int24 newUpper) = PositionAdjustment.calculateAdjustedTicks(
            -1200, -600, 500, true
        );
        
        assertLt(newLower, -1200);
        assertLt(newUpper, -600);
        assertEq(newUpper - newLower, -600 - (-1200));
    }

    function test_CalculateAdjustedTicks_PositiveRange() public {
        (int24 newLower, int24 newUpper) = PositionAdjustment.calculateAdjustedTicks(
            600, 1200, 500, true
        );
        
        assertGt(newLower, 600);
        assertGt(newUpper, 1200);
        assertEq(newUpper - newLower, 1200 - 600);
    }

    function test_CalculateAdjustedTicks_LargeYield() public {
        (int24 newLower, int24 newUpper) = PositionAdjustment.calculateAdjustedTicks(
            -600, 600, 10000, true // 100% yield
        );
        
        // Very large shift expected
        assertGt(newLower, 39400); // 10000 * 4 = 40000 shift
    }

    // Calculate Position Efficiency Tests (10 tests)
    function test_CalculatePositionEfficiency_NoDrift() public {
        uint256 efficiency = PositionAdjustment.calculatePositionEfficiency(
            positionData, 0
        );
        
        assertEq(efficiency, 10000); // 100% efficiency
    }

    function test_CalculatePositionEfficiency_SmallDrift() public {
        uint256 efficiency = PositionAdjustment.calculatePositionEfficiency(
            positionData, 100 // 1% drift
        );
        
        assertEq(efficiency, 9500); // 95% efficiency
    }

    function test_CalculatePositionEfficiency_ModerateDrift() public {
        uint256 efficiency = PositionAdjustment.calculatePositionEfficiency(
            positionData, 1000 // 10% drift
        );
        
        assertEq(efficiency, 5000); // 50% efficiency
    }

    function test_CalculatePositionEfficiency_LargeDrift() public {
        uint256 efficiency = PositionAdjustment.calculatePositionEfficiency(
            positionData, 2000 // 20% drift
        );
        
        assertEq(efficiency, 0); // 0% efficiency
    }

    function test_CalculatePositionEfficiency_MaxDrift() public {
        uint256 efficiency = PositionAdjustment.calculatePositionEfficiency(
            positionData, 10000 // 100% drift
        );
        
        assertEq(efficiency, 0); // 0% efficiency
    }

    function test_CalculatePositionEfficiency_ExcessiveDrift() public {
        uint256 efficiency = PositionAdjustment.calculatePositionEfficiency(
            positionData, 15000 // 150% drift
        );
        
        assertEq(efficiency, 0); // 0% efficiency
    }

    function test_CalculatePositionEfficiency_MidRange() public {
        uint256 efficiency = PositionAdjustment.calculatePositionEfficiency(
            positionData, 500 // 5% drift
        );
        
        assertEq(efficiency, 7500); // 75% efficiency
    }

    function test_CalculatePositionEfficiency_AlmostZero() public {
        uint256 efficiency = PositionAdjustment.calculatePositionEfficiency(
            positionData, 1999 // Just under 20%
        );
        
        assertEq(efficiency, 5); // Very low but not zero
    }

    function test_CalculatePositionEfficiency_BoundaryCase() public {
        uint256 efficiency = PositionAdjustment.calculatePositionEfficiency(
            positionData, 9999 // Just under 100%
        );
        
        assertEq(efficiency, 0); // Should round to 0
    }

    function test_CalculatePositionEfficiency_VerySmallDrift() public {
        uint256 efficiency = PositionAdjustment.calculatePositionEfficiency(
            positionData, 1 // 0.01% drift
        );
        
        assertEq(efficiency, 9995); // 99.95% efficiency
    }

    // Needs Adjustment Tests (10 tests)
    function test_NeedsAdjustment_BelowThreshold() public {
        bool needs = PositionAdjustment.needsAdjustment(
            positionData, 100, 500, 1 hours // yield below threshold
        );
        
        assertFalse(needs);
    }

    function test_NeedsAdjustment_AboveThreshold() public {
        bool needs = PositionAdjustment.needsAdjustment(
            positionData, 600, 500, 1 hours // yield above threshold
        );
        
        assertTrue(needs);
    }

    function test_NeedsAdjustment_WithinCooldown() public {
        positionData.lastYieldAdjustment = block.timestamp - 30 minutes;
        
        bool needs = PositionAdjustment.needsAdjustment(
            positionData, 600, 500, 1 hours // still in cooldown
        );
        
        assertFalse(needs);
    }

    function test_NeedsAdjustment_AfterCooldown() public {
        positionData.lastYieldAdjustment = block.timestamp - 2 hours;
        
        bool needs = PositionAdjustment.needsAdjustment(
            positionData, 600, 500, 1 hours // past cooldown
        );
        
        assertTrue(needs);
    }

    function test_NeedsAdjustment_AutoAdjustDisabled() public {
        positionData.autoAdjustEnabled = false;
        
        bool needs = PositionAdjustment.needsAdjustment(
            positionData, 600, 500, 1 hours
        );
        
        assertFalse(needs);
    }

    function test_NeedsAdjustment_AllConditionsMet() public {
        positionData.lastYieldAdjustment = block.timestamp - 2 hours;
        positionData.autoAdjustEnabled = true;
        
        bool needs = PositionAdjustment.needsAdjustment(
            positionData, 600, 500, 1 hours
        );
        
        assertTrue(needs);
    }

    function test_NeedsAdjustment_ExactThreshold() public {
        bool needs = PositionAdjustment.needsAdjustment(
            positionData, 500, 500, 1 hours // exactly at threshold
        );
        
        assertTrue(needs);
    }

    function test_NeedsAdjustment_ZeroThreshold() public {
        bool needs = PositionAdjustment.needsAdjustment(
            positionData, 100, 0, 1 hours // any yield should trigger
        );
        
        assertTrue(needs);
    }

    function test_NeedsAdjustment_ZeroCooldown() public {
        positionData.lastYieldAdjustment = block.timestamp;
        
        bool needs = PositionAdjustment.needsAdjustment(
            positionData, 600, 500, 0 // no cooldown
        );
        
        assertTrue(needs);
    }

    function test_NeedsAdjustment_ExactCooldownBoundary() public {
        positionData.lastYieldAdjustment = block.timestamp - 1 hours;
        
        bool needs = PositionAdjustment.needsAdjustment(
            positionData, 600, 500, 1 hours // exactly at cooldown boundary
        );
        
        assertTrue(needs);
    }

    // Calculate Optimal Range Tests (10 tests)
    function test_CalculateOptimalRange_BasicCalculation() public {
        (int24 optimalLower, int24 optimalUpper) = PositionAdjustment.calculateOptimalRange(
            -600, 600, 500, true
        );
        
        // Should return valid tick range
        assertTrue(PositionAdjustment.validateTickRange(optimalLower, optimalUpper));
    }

    function test_CalculateOptimalRange_RangeWidthPreserved() public {
        int24 originalWidth = 600 - (-600);
        
        (int24 optimalLower, int24 optimalUpper) = PositionAdjustment.calculateOptimalRange(
            -600, 600, 500, true
        );
        
        assertEq(optimalUpper - optimalLower, originalWidth);
    }

    function test_CalculateOptimalRange_ZeroYield() public {
        (int24 optimalLower, int24 optimalUpper) = PositionAdjustment.calculateOptimalRange(
            -600, 600, 0, true
        );
        
        // With zero expected yield, optimal should be close to current
        assertGe(optimalLower, -700);
        assertLe(optimalUpper, 700);
    }

    function test_CalculateOptimalRange_HighYield() public {
        (int24 optimalLower, int24 optimalUpper) = PositionAdjustment.calculateOptimalRange(
            -600, 600, 2000, true // 20% yield
        );
        
        assertTrue(PositionAdjustment.validateTickRange(optimalLower, optimalUpper));
    }

    function test_CalculateOptimalRange_LSTToken1() public {
        (int24 optimalLower, int24 optimalUpper) = PositionAdjustment.calculateOptimalRange(
            -600, 600, 500, false
        );
        
        assertTrue(PositionAdjustment.validateTickRange(optimalLower, optimalUpper));
    }

    function test_CalculateOptimalRange_AsymmetricInput() public {
        (int24 optimalLower, int24 optimalUpper) = PositionAdjustment.calculateOptimalRange(
            -1200, 300, 500, true
        );
        
        assertEq(optimalUpper - optimalLower, 300 - (-1200));
    }

    function test_CalculateOptimalRange_LargeRange() public {
        (int24 optimalLower, int24 optimalUpper) = PositionAdjustment.calculateOptimalRange(
            -10000, 10000, 500, true
        );
        
        assertEq(optimalUpper - optimalLower, 20000);
    }

    function test_CalculateOptimalRange_SmallRange() public {
        (int24 optimalLower, int24 optimalUpper) = PositionAdjustment.calculateOptimalRange(
            -60, 60, 500, true
        );
        
        assertEq(optimalUpper - optimalLower, 120);
    }

    function test_CalculateOptimalRange_NegativeRange() public {
        (int24 optimalLower, int24 optimalUpper) = PositionAdjustment.calculateOptimalRange(
            -1200, -600, 500, true
        );
        
        assertTrue(PositionAdjustment.validateTickRange(optimalLower, optimalUpper));
    }

    function test_CalculateOptimalRange_PositiveRange() public {
        (int24 optimalLower, int24 optimalUpper) = PositionAdjustment.calculateOptimalRange(
            600, 1200, 500, true
        );
        
        assertTrue(PositionAdjustment.validateTickRange(optimalLower, optimalUpper));
    }
}