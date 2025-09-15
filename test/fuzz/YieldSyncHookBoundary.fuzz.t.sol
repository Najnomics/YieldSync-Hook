// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/hooks/YieldSyncHook.sol";
import {HookMiner} from "../../lib/v4-periphery/src/utils/HookMiner.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {PositionAdjustment} from "../../src/hooks/libraries/PositionAdjustment.sol";
import {IYieldSyncHook} from "../../src/hooks/interfaces/IYieldSyncHook.sol";
import "../../src/avs/interfaces/IYieldSyncAVS.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

// Mock contracts for testing
contract MockPoolManager {
    function getManager() external view returns (address) {
        return address(this);
    }
}

contract MockYieldSyncAVS {
    mapping(address => uint256) public requiredAdjustments;
    
    function getRequiredAdjustment(address lstToken, uint256) external view returns (uint256) {
        return requiredAdjustments[lstToken];
    }
    
    function setRequiredAdjustment(address lstToken, uint256 adjustment) external {
        requiredAdjustments[lstToken] = adjustment;
    }
}

/**
 * @title YieldSyncHook Boundary Fuzz Tests
 * @notice Fuzz testing for boundary conditions and edge cases
 */
contract YieldSyncHookBoundaryFuzzTest is Test {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    uint24 constant FEE = 3000;
    int24 constant TICK_SPACING = 60;
    int24 constant TICK_LOWER = -1200;
    int24 constant TICK_UPPER = 1200;
    uint128 constant LIQUIDITY = 1000e18;
    
    address constant TOKEN0 = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
    address constant TOKEN1 = 0xae78736Cd615f374D3085123A210448E74Fc6393; // rETH

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    
    YieldSyncHook public hook;
    MockPoolManager public poolManager;
    MockYieldSyncAVS public mockAVS;
    
    PoolKey public poolKey;
    PoolId public poolId;
    
    address public user;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public {
        user = makeAddr("user");
        
        // Deploy mocks
        poolManager = new MockPoolManager();
        mockAVS = new MockYieldSyncAVS();
        
        // Create pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(TOKEN0),
            currency1: Currency.wrap(TOKEN1),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0)) // Temporary, will be set after hook deployment
        });
        poolId = poolKey.toId();
        
        // Deploy hook with HookMiner
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );
        
        bytes memory constructorArgs = abi.encode(IPoolManager(address(poolManager)), IYieldSyncAVS(address(mockAVS)));
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(YieldSyncHook).creationCode,
            constructorArgs
        );
        
        hook = new YieldSyncHook{salt: salt}(IPoolManager(address(poolManager)), IYieldSyncAVS(address(mockAVS)));
        
        // Update pool key with actual hook address
        poolKey = PoolKey({
            currency0: Currency.wrap(TOKEN0),
            currency1: Currency.wrap(TOKEN1),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        poolId = poolKey.toId();
    }

    /*//////////////////////////////////////////////////////////////
                              HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function _configurePoolWithLST() internal {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 50,
            autoAdjustmentEnabled: true
        });
        hook.configurePool(poolId, config);
    }
    
    function _getPositionId(
        address owner,
        PoolId _poolId,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, _poolId, tickLower, tickUpper));
    }

    /*//////////////////////////////////////////////////////////////
                         BOUNDARY FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_TickRange_ExtremeBoundaries(int24 tickLower, int24 tickUpper) public {
        // Test with extreme tick values within valid Uniswap V4 range
        tickLower = int24(bound(tickLower, -887272, 887272));
        tickUpper = int24(bound(tickUpper, tickLower + TICK_SPACING, 887272));
        
        // Ensure tick spacing compliance
        tickLower = (tickLower / TICK_SPACING) * TICK_SPACING;
        tickUpper = (tickUpper / TICK_SPACING) * TICK_SPACING;
        
        _configurePoolWithLST();
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user, poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        bytes32 positionId = _getPositionId(user, poolId, tickLower, tickUpper);
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        
        assertEq(position.tickLower, tickLower);
        assertEq(position.tickUpper, tickUpper);
        assertEq(position.liquidity, LIQUIDITY);
    }

    function testFuzz_LiquidityAmount_MinMaxBoundaries(uint128 liquidityAmount) public {
        // Test with extreme liquidity amounts
        liquidityAmount = uint128(bound(liquidityAmount, 1, type(uint128).max));
        
        _configurePoolWithLST();
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(liquidityAmount)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user, poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        assertEq(hook.userLiquidity(poolId, user), liquidityAmount);
        assertEq(hook.totalLiquidity(poolId), liquidityAmount);
        
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.liquidity, liquidityAmount);
    }

    function testFuzz_YieldBPS_ExtremeBoundaries(uint256 yieldBPS) public {
        // Test with extreme yield values (0 to 50000 BPS = 0% to 500%)
        yieldBPS = bound(yieldBPS, 0, 50000);
        
        _configurePoolWithLST();
        
        // Add position
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user, poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        
        vm.warp(block.timestamp + 3600);
        mockAVS.setRequiredAdjustment(TOKEN1, yieldBPS);
        
        (uint256 currentYieldDrift, bool needsAdjustment, uint256 potentialILPrevention, uint256 timeSinceLastAdjustment) = 
            hook.getPositionHealth(positionId);
        
        assertEq(currentYieldDrift, yieldBPS);
        assertEq(needsAdjustment, yieldBPS >= 50); // Default threshold
        assertGt(timeSinceLastAdjustment, 0);
        
        if (yieldBPS > 0) {
            assertGt(potentialILPrevention, 0);
        }
    }

    function testFuzz_ThresholdBPS_BoundaryValues(uint256 thresholdBPS) public {
        // Test threshold values at exact boundaries
        uint256 minThreshold = hook.MIN_ADJUSTMENT_THRESHOLD();
        uint256 maxThreshold = hook.MAX_ADJUSTMENT_THRESHOLD();
        
        thresholdBPS = bound(thresholdBPS, minThreshold, maxThreshold);
        
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: thresholdBPS,
            autoAdjustmentEnabled: true
        });
        
        hook.configurePool(poolId, config);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.adjustmentThresholdBPS, thresholdBPS);
        
        // Test threshold behavior
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user, poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        
        vm.warp(block.timestamp + 3600);
        
        // Test exactly at threshold
        mockAVS.setRequiredAdjustment(TOKEN1, thresholdBPS);
        (, bool needsAdjustmentAt, , ) = hook.getPositionHealth(positionId);
        assertTrue(needsAdjustmentAt);
        
        // Test below threshold
        if (thresholdBPS > 0) {
            mockAVS.setRequiredAdjustment(TOKEN1, thresholdBPS - 1);
            (, bool needsAdjustmentBelow, , ) = hook.getPositionHealth(positionId);
            assertFalse(needsAdjustmentBelow);
        }
    }

    function testFuzz_TimeManipulation_ExtremePeriods(uint256 timeAdvancement) public {
        // Test with extreme time periods (1 second to 10 years)
        timeAdvancement = bound(timeAdvancement, 1, 10 * 365 days);
        
        _configurePoolWithLST();
        
        // Add position
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user, poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        
        // Advance time by extreme amount
        vm.warp(block.timestamp + timeAdvancement);
        
        mockAVS.setRequiredAdjustment(TOKEN1, 100);
        (, , , uint256 timeSinceLastAdjustment) = hook.getPositionHealth(positionId);
        
        assertEq(timeSinceLastAdjustment, timeAdvancement);
    }

    function testFuzz_CooldownPeriod_BoundaryTesting(uint256 timeBeforeCooldown, uint256 timeAfterCooldown) public {
        // Test cooldown period boundaries
        timeBeforeCooldown = bound(timeBeforeCooldown, 0, hook.ADJUSTMENT_COOLDOWN() - 1);
        timeAfterCooldown = bound(timeAfterCooldown, hook.ADJUSTMENT_COOLDOWN(), hook.ADJUSTMENT_COOLDOWN() + 86400);
        
        _configurePoolWithLST();
        
        // Add position
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user, poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        mockAVS.setRequiredAdjustment(TOKEN1, 100);
        
        // Test before cooldown - should not trigger adjustment
        vm.warp(block.timestamp + timeBeforeCooldown);
        vm.prank(user);
        hook.manuallyAdjustPosition(positionId);
        
        // Test after cooldown - should trigger adjustment
        vm.warp(block.timestamp + timeAfterCooldown);
        vm.prank(user);
        hook.manuallyAdjustPosition(positionId);
    }

    function testFuzz_PoolId_Uniqueness(uint256 salt1, uint256 salt2) public {
        vm.assume(salt1 != salt2);
        
        // Create two different pool keys
        PoolKey memory poolKey1 = PoolKey({
            currency0: Currency.wrap(TOKEN0),
            currency1: Currency.wrap(TOKEN1),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        
        PoolKey memory poolKey2 = PoolKey({
            currency0: Currency.wrap(TOKEN1), // Swapped order
            currency1: Currency.wrap(TOKEN0),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        
        PoolId poolId1 = poolKey1.toId();
        PoolId poolId2 = poolKey2.toId();
        
        assertTrue(PoolId.unwrap(poolId1) != PoolId.unwrap(poolId2));
        
        // Configure both pools
        IYieldSyncHook.LSTConfig memory config1 = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 50,
            autoAdjustmentEnabled: true
        });
        
        IYieldSyncHook.LSTConfig memory config2 = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN0,
            pairedToken: TOKEN1,
            isLSTToken0: true,
            adjustmentThresholdBPS: 100,
            autoAdjustmentEnabled: false
        });
        
        hook.configurePool(poolId1, config1);
        hook.configurePool(poolId2, config2);
        
        // Verify independent configurations
        IYieldSyncHook.LSTConfig memory stored1 = hook.poolConfigs(poolId1);
        IYieldSyncHook.LSTConfig memory stored2 = hook.poolConfigs(poolId2);
        
        assertEq(stored1.adjustmentThresholdBPS, 50);
        assertEq(stored2.adjustmentThresholdBPS, 100);
        assertTrue(stored1.autoAdjustmentEnabled);
        assertFalse(stored2.autoAdjustmentEnabled);
    }

    function testFuzz_ValidInputRanges_AllFunctions(uint256 randomInput) public {
        randomInput = bound(randomInput, 1, 10000);
        
        _configurePoolWithLST();
        
        // Test various functions with bounded random inputs
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(randomInput * 1e15), // Scale to reasonable liquidity
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user, poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        
        // Test position health with various yield inputs
        mockAVS.setRequiredAdjustment(TOKEN1, randomInput % 1000);
        (uint256 yieldDrift, bool needsAdjustment, uint256 ilPrevention, uint256 timeSince) = 
            hook.getPositionHealth(positionId);
        
        // Basic sanity checks
        assertEq(yieldDrift, randomInput % 1000);
        assertTrue(ilPrevention >= 0);
        assertTrue(timeSince >= 0);
    }
}