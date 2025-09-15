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
 * @title YieldSyncHook Fuzz Tests
 * @notice Comprehensive fuzz testing for YieldSyncHook core functionality
 */
contract YieldSyncHookFuzzTest is Test {
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
                              FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ConfigurePool_ValidThreshold(uint256 adjustmentThresholdBPS) public {
        // Bound to valid range
        adjustmentThresholdBPS = bound(adjustmentThresholdBPS, hook.MIN_ADJUSTMENT_THRESHOLD(), hook.MAX_ADJUSTMENT_THRESHOLD());
        
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: adjustmentThresholdBPS,
            autoAdjustmentEnabled: true
        });
        
        hook.configurePool(poolId, config);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.adjustmentThresholdBPS, adjustmentThresholdBPS);
    }

    function testFuzz_GetPositionHealth_YieldDrift(uint256 yieldBPS) public {
        // Bound yield to reasonable range (0-1000 BPS = 0-10%)
        yieldBPS = bound(yieldBPS, 0, 1000);
        
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
        
        vm.warp(block.timestamp + 3600); // Advance time
        mockAVS.setRequiredAdjustment(TOKEN1, yieldBPS);
        
        (uint256 currentYieldDrift, bool needsAdjustment, uint256 potentialILPrevention, uint256 timeSinceLastAdjustment) = 
            hook.getPositionHealth(positionId);
        
        assertEq(currentYieldDrift, yieldBPS);
        assertEq(needsAdjustment, yieldBPS >= 50); // Default threshold is 50 BPS
        assertGt(timeSinceLastAdjustment, 0);
        
        if (yieldBPS > 0) {
            assertGt(potentialILPrevention, 0);
        }
    }

    function testFuzz_AddLiquidity_DifferentAmounts(uint128 liquidityAmount) public {
        // Bound to reasonable liquidity amounts (1e15 to 1e24)
        liquidityAmount = uint128(bound(liquidityAmount, 1e15, 1e24));
        
        _configurePoolWithLST();
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(liquidityAmount)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(
            user,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        
        assertEq(position.liquidity, liquidityAmount);
        assertEq(hook.userLiquidity(poolId, user), liquidityAmount);
        assertEq(hook.totalLiquidity(poolId), liquidityAmount);
    }

    function testFuzz_RemoveLiquidity_PartialRemoval(uint128 initialLiquidity, uint128 removeAmount) public {
        // Bound to reasonable amounts
        initialLiquidity = uint128(bound(initialLiquidity, 1e18, 1e24));
        removeAmount = uint128(bound(removeAmount, 1e15, initialLiquidity));
        
        _configurePoolWithLST();
        
        // Add initial liquidity
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(initialLiquidity)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(
            user,
            poolKey,
            addParams,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        // Remove partial liquidity
        ModifyLiquidityParams memory removeParams = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: -int256(uint256(removeAmount)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterRemoveLiquidity(
            user,
            poolKey,
            removeParams,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        uint256 expectedRemaining = initialLiquidity - removeAmount;
        assertEq(hook.userLiquidity(poolId, user), expectedRemaining);
        assertEq(hook.totalLiquidity(poolId), expectedRemaining);
    }

    function testFuzz_PositionId_Uniqueness(
        address owner1,
        address owner2,
        int24 tickLower1,
        int24 tickLower2,
        int24 tickUpper1,
        int24 tickUpper2
    ) public view {
        // Ensure different parameters create different position IDs
        vm.assume(owner1 != owner2 || tickLower1 != tickLower2 || tickUpper1 != tickUpper2);
        
        bytes32 positionId1 = _getPositionId(owner1, poolId, tickLower1, tickUpper1);
        bytes32 positionId2 = _getPositionId(owner2, poolId, tickLower2, tickUpper2);
        
        assertTrue(positionId1 != positionId2);
    }

    function testFuzz_AutoAdjustment_Toggle(bool initialState, bool newState) public {
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
        
        // Set initial state
        vm.prank(user);
        hook.setAutoAdjustment(positionId, initialState);
        
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.autoAdjustEnabled, initialState);
        
        // Change to new state
        vm.prank(user);
        hook.setAutoAdjustment(positionId, newState);
        
        position = hook.positions(positionId);
        assertEq(position.autoAdjustEnabled, newState);
    }

    function testFuzz_ConfigurePool_TokenAddresses(address lstToken, address pairedToken) public {
        // Ensure valid addresses
        vm.assume(lstToken != address(0) && pairedToken != address(0));
        vm.assume(lstToken != pairedToken);
        
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: lstToken,
            pairedToken: pairedToken,
            isLSTToken0: false,
            adjustmentThresholdBPS: 100,
            autoAdjustmentEnabled: true
        });
        
        hook.configurePool(poolId, config);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.lstToken, lstToken);
        assertEq(storedConfig.pairedToken, pairedToken);
    }

    function testFuzz_YieldCalculations_ILPrevention(uint128 liquidity, uint256 yieldBPS) public {
        // Bound to reasonable values
        liquidity = uint128(bound(liquidity, 1e15, 1e24));
        yieldBPS = bound(yieldBPS, 1, 1000); // 0.01% to 10%
        
        _configurePoolWithLST();
        
        // Add position
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(liquidity)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user, poolKey, params, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        
        mockAVS.setRequiredAdjustment(TOKEN1, yieldBPS);
        
        (, , uint256 potentialILPrevention, ) = hook.getPositionHealth(positionId);
        
        // IL prevention should increase with both liquidity and yield
        assertGt(potentialILPrevention, 0);
        
        // Test with higher yield
        mockAVS.setRequiredAdjustment(TOKEN1, yieldBPS * 2);
        (, , uint256 higherILPrevention, ) = hook.getPositionHealth(positionId);
        
        assertGt(higherILPrevention, potentialILPrevention);
    }
}