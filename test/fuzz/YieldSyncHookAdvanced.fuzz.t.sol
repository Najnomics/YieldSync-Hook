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
 * @title YieldSyncHook Advanced Fuzz Tests
 * @notice Advanced fuzz testing scenarios for complex interactions
 */
contract YieldSyncHookAdvancedFuzzTest is Test {
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
                         ADVANCED FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_MultipleUsers_LiquidityTracking(
        address[5] memory users,
        uint128[5] memory liquidityAmounts
    ) public {
        // Ensure unique valid users
        for (uint256 i = 0; i < 5; i++) {
            vm.assume(users[i] != address(0) && users[i] != address(hook) && users[i] != address(poolManager));
            liquidityAmounts[i] = uint128(bound(liquidityAmounts[i], 1e15, 1e23));
            
            for (uint256 j = i + 1; j < 5; j++) {
                vm.assume(users[i] != users[j]);
            }
        }
        
        _configurePoolWithLST();
        
        uint256 totalExpected = 0;
        
        for (uint256 i = 0; i < 5; i++) {
            ModifyLiquidityParams memory params = ModifyLiquidityParams({
                tickLower: TICK_LOWER + int24(int256(i * 60)), // Different tick ranges
                tickUpper: TICK_UPPER + int24(int256(i * 60)),
                liquidityDelta: int256(uint256(liquidityAmounts[i])),
                salt: bytes32(0)
            });
            
            vm.prank(address(poolManager));
            hook.afterAddLiquidity(users[i], poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
            
            totalExpected += liquidityAmounts[i];
            assertEq(hook.userLiquidity(poolId, users[i]), liquidityAmounts[i]);
        }
        
        assertEq(hook.totalLiquidity(poolId), totalExpected);
    }

    function testFuzz_PositionLifecycle_RandomizedInputs(
        address randomUser,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidityAmount,
        uint256 yieldBPS,
        uint256 adjustmentThresholdBPS,
        bool autoAdjustEnabled
    ) public {
        // Sanitize inputs
        vm.assume(randomUser != address(0) && randomUser != address(hook) && randomUser != address(poolManager));
        tickLower = int24(bound(tickLower, -887220, 887220)); // Valid tick range with spacing
        tickUpper = int24(bound(tickUpper, tickLower + 60, 887272)); // Ensure upper > lower
        liquidityAmount = uint128(bound(liquidityAmount, 1e15, 1e24));
        yieldBPS = bound(yieldBPS, 0, 1000);
        adjustmentThresholdBPS = bound(adjustmentThresholdBPS, hook.MIN_ADJUSTMENT_THRESHOLD(), hook.MAX_ADJUSTMENT_THRESHOLD());
        
        // Configure pool with random threshold
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: adjustmentThresholdBPS,
            autoAdjustmentEnabled: autoAdjustEnabled
        });
        hook.configurePool(poolId, config);
        
        // Add liquidity with random parameters
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(uint256(liquidityAmount)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(
            randomUser,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        // Verify position creation
        bytes32 positionId = _getPositionId(randomUser, poolId, tickLower, tickUpper);
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        
        assertEq(position.owner, randomUser);
        assertEq(position.liquidity, liquidityAmount);
        assertEq(position.tickLower, tickLower);
        assertEq(position.tickUpper, tickUpper);
        assertTrue(position.autoAdjustEnabled); // Default is true
        
        // Test position health with random yield
        vm.warp(block.timestamp + 3600);
        mockAVS.setRequiredAdjustment(TOKEN1, yieldBPS);
        
        (uint256 currentYieldDrift, bool needsAdjustment, uint256 potentialILPrevention, uint256 timeSinceLastAdjustment) = 
            hook.getPositionHealth(positionId);
        
        assertEq(currentYieldDrift, yieldBPS);
        assertEq(needsAdjustment, yieldBPS >= adjustmentThresholdBPS);
        assertGt(timeSinceLastAdjustment, 0);
        
        if (yieldBPS > 0) {
            assertGt(potentialILPrevention, 0);
        }
    }

    function testFuzz_MultipleOperations_RandomSequence(
        uint8 operationCount,
        bytes32 randomSeed
    ) public {
        operationCount = uint8(bound(operationCount, 1, 10));
        _configurePoolWithLST();
        
        bytes32 positionId;
        bool positionExists = false;
        
        for (uint256 i = 0; i < operationCount; i++) {
            uint256 operation = uint256(keccak256(abi.encode(randomSeed, i))) % 5;
            
            if (operation == 0 && !positionExists) {
                // Add liquidity
                uint128 liquidity = uint128(bound(uint256(keccak256(abi.encode(randomSeed, i, "liquidity"))), 1e15, 1e20));
                
                ModifyLiquidityParams memory params = ModifyLiquidityParams({
                    tickLower: TICK_LOWER,
                    tickUpper: TICK_UPPER,
                    liquidityDelta: int256(uint256(liquidity)),
                    salt: bytes32(0)
                });
                
                vm.prank(address(poolManager));
                hook.afterAddLiquidity(user, poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
                
                positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
                positionExists = true;
                
            } else if (operation == 1 && positionExists) {
                // Toggle auto-adjustment
                bool autoAdjust = uint256(keccak256(abi.encode(randomSeed, i, "auto"))) % 2 == 0;
                vm.prank(user);
                hook.setAutoAdjustment(positionId, autoAdjust);
                
            } else if (operation == 2 && positionExists) {
                // Check position health
                uint256 yieldBPS = bound(uint256(keccak256(abi.encode(randomSeed, i, "yield"))), 0, 500);
                mockAVS.setRequiredAdjustment(TOKEN1, yieldBPS);
                hook.getPositionHealth(positionId);
                
            } else if (operation == 3 && positionExists) {
                // Manual adjustment attempt
                vm.prank(user);
                hook.manuallyAdjustPosition(positionId);
                
            } else if (operation == 4 && positionExists) {
                // Time warp
                uint256 timeJump = bound(uint256(keccak256(abi.encode(randomSeed, i, "time"))), 1, 86400);
                vm.warp(block.timestamp + timeJump);
            }
        }
        
        // Final verification if position exists
        if (positionExists) {
            PositionAdjustment.PositionData memory position = hook.positions(positionId);
            assertTrue(position.owner != address(0));
        }
    }

    function testFuzz_EdgeCases_ExtremeValues(
        uint256 extremeYield,
        uint256 extremeTime,
        uint128 extremeLiquidity
    ) public {
        extremeYield = bound(extremeYield, 0, 50000); // Up to 500% yield
        extremeTime = bound(extremeTime, 1, 365 days);
        extremeLiquidity = uint128(bound(extremeLiquidity, 1, type(uint128).max));
        
        _configurePoolWithLST();
        
        // Skip if liquidity is too small for meaningful test
        if (extremeLiquidity < 1e12) return;
        
        // Add position with extreme liquidity
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(extremeLiquidity)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user, poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        
        // Test with extreme time advancement
        vm.warp(block.timestamp + extremeTime);
        
        // Test with extreme yield
        mockAVS.setRequiredAdjustment(TOKEN1, extremeYield);
        
        (uint256 yieldDrift, bool needsAdjustment, uint256 ilPrevention, uint256 timeSince) = 
            hook.getPositionHealth(positionId);
        
        assertEq(yieldDrift, extremeYield);
        assertEq(needsAdjustment, extremeYield >= 50); // Default threshold
        assertEq(timeSince, extremeTime);
        
        if (extremeYield > 0) {
            assertGt(ilPrevention, 0);
        }
    }

    function testFuzz_ConcurrentUsers_RandomBehavior(
        address[3] memory users,
        uint128[3] memory liquidityAmounts,
        uint256[3] memory yieldInputs,
        bool[3] memory autoAdjustSettings
    ) public {
        // Ensure unique valid users
        for (uint256 i = 0; i < 3; i++) {
            vm.assume(users[i] != address(0) && users[i] != address(hook) && users[i] != address(poolManager));
            liquidityAmounts[i] = uint128(bound(liquidityAmounts[i], 1e15, 1e22));
            yieldInputs[i] = bound(yieldInputs[i], 0, 1000);
            
            for (uint256 j = i + 1; j < 3; j++) {
                vm.assume(users[i] != users[j]);
            }
        }
        
        _configurePoolWithLST();
        bytes32[3] memory positionIds;
        
        // Each user adds liquidity
        for (uint256 i = 0; i < 3; i++) {
            ModifyLiquidityParams memory params = ModifyLiquidityParams({
                tickLower: TICK_LOWER + int24(int256(i * 60)), // Different ranges
                tickUpper: TICK_UPPER + int24(int256(i * 60)),
                liquidityDelta: int256(uint256(liquidityAmounts[i])),
                salt: bytes32(0)
            });
            
            vm.prank(address(poolManager));
            hook.afterAddLiquidity(users[i], poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
            
            positionIds[i] = _getPositionId(users[i], poolId, TICK_LOWER + int24(int256(i * 60)), TICK_UPPER + int24(int256(i * 60)));
            
            // Set auto-adjustment preference
            vm.prank(users[i]);
            hook.setAutoAdjustment(positionIds[i], autoAdjustSettings[i]);
        }
        
        // Verify independent position management
        uint256 totalExpectedLiquidity = 0;
        for (uint256 i = 0; i < 3; i++) {
            totalExpectedLiquidity += liquidityAmounts[i];
            assertEq(hook.userLiquidity(poolId, users[i]), liquidityAmounts[i]);
            
            PositionAdjustment.PositionData memory position = hook.positions(positionIds[i]);
            assertEq(position.autoAdjustEnabled, autoAdjustSettings[i]);
        }
        
        assertEq(hook.totalLiquidity(poolId), totalExpectedLiquidity);
        
        // Test concurrent yield adjustments
        vm.warp(block.timestamp + 3600);
        for (uint256 i = 0; i < 3; i++) {
            mockAVS.setRequiredAdjustment(TOKEN1, yieldInputs[i]);
            (uint256 yieldDrift, , , ) = hook.getPositionHealth(positionIds[i]);
            assertEq(yieldDrift, yieldInputs[i]);
        }
    }
}