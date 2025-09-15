// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/hooks/YieldSyncHook.sol";
import {HookMiner} from "../../lib/v4-periphery/src/utils/HookMiner.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import "../../src/hooks/interfaces/IYieldSyncHook.sol";
import "../../src/avs/interfaces/IYieldSyncAVS.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {PositionAdjustment} from "../../src/hooks/libraries/PositionAdjustment.sol";

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

contract YieldSyncHookUnitTest is Test {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    YieldSyncHook public hook;
    MockPoolManager public poolManager;
    MockYieldSyncAVS public mockAVS;
    PoolKey public poolKey;
    PoolId public poolId;
    
    // Test addresses
    address public owner;
    address public user;
    address public user2;
    
    // Test constants
    address constant TOKEN0 = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
    address constant TOKEN1 = 0xae78736Cd615f374D3085123A210448E74Fc6393; // rETH (LST)
    int24 constant TICK_SPACING = 60;
    uint24 constant FEE = 3000;
    int24 constant TICK_LOWER = -1200;
    int24 constant TICK_UPPER = 1200;
    uint128 constant LIQUIDITY = 1000000000000000000; // 1e18

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        user2 = makeAddr("user2");
        
        // Deploy mocks
        poolManager = new MockPoolManager();
        mockAVS = new MockYieldSyncAVS();
        
        // Deploy hook using HookMiner to get valid address
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );
        
        // Mine for a valid hook address
        bytes memory constructorArgs = abi.encode(IPoolManager(address(poolManager)), IYieldSyncAVS(address(mockAVS)));
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(YieldSyncHook).creationCode,
            constructorArgs
        );
        
        // Deploy the hook with the found salt
        hook = new YieldSyncHook{salt: salt}(IPoolManager(address(poolManager)), IYieldSyncAVS(address(mockAVS)));
        
        // Verify the address matches
        require(address(hook) == hookAddress, "YieldSyncHookTest: hook address mismatch");
        
        // Set up pool key
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
                                CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsPoolManager() public {
        assertEq(address(hook.poolManager()), address(poolManager));
    }

    function test_Constructor_SetsOwner() public {
        assertEq(hook.owner(), owner);
    }

    function test_Constructor_SetsYieldSyncAVS() public {
        assertEq(address(hook.yieldSyncAVS()), address(mockAVS));
    }

    function test_Constructor_ValidAddress() public {
        assertTrue(address(hook) != address(0));
    }

    function test_Constructor_InitialState() public {
        // Pool should not be configured yet
        IYieldSyncHook.LSTConfig memory config = hook.poolConfigs(poolId);
        assertEq(config.lstToken, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK PERMISSIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetHookPermissions_AfterInitialize() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.afterInitialize);
    }

    function test_GetHookPermissions_AfterAddLiquidity() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.afterAddLiquidity);
    }

    function test_GetHookPermissions_BeforeRemoveLiquidity() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.beforeRemoveLiquidity);
    }

    function test_GetHookPermissions_AfterRemoveLiquidity() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.afterRemoveLiquidity);
    }

    function test_GetHookPermissions_DisabledPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.beforeAddLiquidity);
        assertFalse(permissions.beforeSwap);
        assertFalse(permissions.afterSwap);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
    }

    /*//////////////////////////////////////////////////////////////
                         POOL CONFIGURATION TESTS  
    //////////////////////////////////////////////////////////////*/

    function test_ConfigurePool_ValidConfiguration() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 50,
            autoAdjustmentEnabled: true
        });
        
        vm.expectEmit(true, true, true, true);
        emit PoolConfigured(poolId, TOKEN1, TOKEN0, true);
        
        hook.configurePool(poolId, config);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.lstToken, TOKEN1);
        assertEq(storedConfig.pairedToken, TOKEN0);
        assertFalse(storedConfig.isLSTToken0);
        assertEq(storedConfig.adjustmentThresholdBPS, 50);
        assertTrue(storedConfig.autoAdjustmentEnabled);
    }

    function test_ConfigurePool_OnlyOwner() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 50,
            autoAdjustmentEnabled: true
        });
        
        vm.prank(user);
        vm.expectRevert();
        hook.configurePool(poolId, config);
    }

    function test_ConfigurePool_InvalidLSTToken() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: address(0),
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 50,
            autoAdjustmentEnabled: true
        });
        
        vm.expectRevert("YieldSync: invalid LST token");
        hook.configurePool(poolId, config);
    }

    function test_ConfigurePool_ThresholdTooLow() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 5, // Below MIN_ADJUSTMENT_THRESHOLD (10)
            autoAdjustmentEnabled: true
        });
        
        vm.expectRevert("YieldSync: threshold too low");
        hook.configurePool(poolId, config);
    }

    function test_ConfigurePool_ThresholdTooHigh() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 600, // Above MAX_ADJUSTMENT_THRESHOLD (500)
            autoAdjustmentEnabled: true
        });
        
        vm.expectRevert("YieldSync: threshold too high");
        hook.configurePool(poolId, config);
    }

    function test_ConfigurePool_MinValidThreshold() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 10, // MIN_ADJUSTMENT_THRESHOLD
            autoAdjustmentEnabled: true
        });
        
        hook.configurePool(poolId, config);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.adjustmentThresholdBPS, 10);
    }

    function test_ConfigurePool_MaxValidThreshold() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 500, // MAX_ADJUSTMENT_THRESHOLD
            autoAdjustmentEnabled: true
        });
        
        hook.configurePool(poolId, config);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.adjustmentThresholdBPS, 500);
    }

    /*//////////////////////////////////////////////////////////////
                            AFTER INITIALIZE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AfterInitialize_AutoDetectsLST() public {
        // This should auto-detect rETH as LST and configure pool
        vm.expectEmit(true, true, true, true);
        emit PoolConfigured(poolId, TOKEN1, TOKEN0, true);
        
        vm.prank(address(poolManager));
        bytes4 selector = hook.afterInitialize(
            address(0),
            poolKey,
            0,
            0,
            ""
        );
        
        assertEq(selector, BaseHook.afterInitialize.selector);
        
        IYieldSyncHook.LSTConfig memory config = hook.poolConfigs(poolId);
        assertEq(config.lstToken, TOKEN1); // rETH detected as LST
        assertEq(config.pairedToken, TOKEN0); // DAI as paired token
        assertFalse(config.isLSTToken0); // rETH is token1
        assertEq(config.adjustmentThresholdBPS, 50); // Default threshold
        assertTrue(config.autoAdjustmentEnabled);
    }

    function test_AfterInitialize_NoLSTDetected() public {
        // Create pool with no LST tokens
        PoolKey memory noLSTKey = PoolKey({
            currency0: Currency.wrap(TOKEN0), // DAI
            currency1: Currency.wrap(0x6B175474E89094C44Da98b954EedeAC495271d0F), // DAI again
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        
        vm.prank(address(poolManager));
        bytes4 selector = hook.afterInitialize(
            address(0),
            noLSTKey,
            0,
            0,
            ""
        );
        
        assertEq(selector, BaseHook.afterInitialize.selector);
        
        // Pool should not be configured
        PoolId noLSTPoolId = noLSTKey.toId();
        IYieldSyncHook.LSTConfig memory config = hook.poolConfigs(noLSTPoolId);
        assertEq(config.lstToken, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                         POSITION MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AfterAddLiquidity_RegistersPosition() public {
        // First configure pool
        _configurePoolWithLST();
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.expectEmit(true, true, true, true);
        bytes32 expectedPositionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        emit PositionRegistered(expectedPositionId, user, TOKEN1, TICK_LOWER, TICK_UPPER, LIQUIDITY);
        
        vm.prank(address(poolManager));
        (bytes4 selector, BalanceDelta delta) = hook.afterAddLiquidity(
            user,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        assertEq(selector, BaseHook.afterAddLiquidity.selector);
        assertEq(BalanceDelta.unwrap(delta), 0);
        
        // Check position was registered
        PositionAdjustment.PositionData memory position = hook.positions(expectedPositionId);
        assertEq(position.owner, user);
        assertEq(PoolId.unwrap(position.poolId), PoolId.unwrap(poolId));
        assertEq(position.tickLower, TICK_LOWER);
        assertEq(position.tickUpper, TICK_UPPER);
        assertEq(position.liquidity, LIQUIDITY);
        assertEq(position.lstToken, TOKEN1);
        assertTrue(position.autoAdjustEnabled);
        
        // Check liquidity tracking
        assertEq(hook.userLiquidity(poolId, user), LIQUIDITY);
        assertEq(hook.totalLiquidity(poolId), LIQUIDITY);
    }

    function test_AfterAddLiquidity_IgnoresNonLSTPool() public {
        // Don't configure pool - no LST detected
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        (bytes4 selector, BalanceDelta delta) = hook.afterAddLiquidity(
            user,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        assertEq(selector, BaseHook.afterAddLiquidity.selector);
        
        // Check position was NOT registered
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.owner, address(0));
        
        // Check liquidity tracking should be 0
        assertEq(hook.userLiquidity(poolId, user), 0);
        assertEq(hook.totalLiquidity(poolId), 0);
    }

    function test_AfterAddLiquidity_IgnoresNegativeLiquidity() public {
        _configurePoolWithLST();
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: -int256(uint256(LIQUIDITY)), // Negative liquidity
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        (bytes4 selector, BalanceDelta delta) = hook.afterAddLiquidity(
            user,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        assertEq(selector, BaseHook.afterAddLiquidity.selector);
        
        // Check position was NOT registered
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.owner, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                       REMOVE LIQUIDITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BeforeRemoveLiquidity_ChecksAdjustment() public {
        _configurePoolWithLST();
        _addLiquidityPosition(user);
        
        // Set required adjustment in mock AVS
        mockAVS.setRequiredAdjustment(TOKEN1, 100); // Above threshold
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: -int256(uint256(LIQUIDITY/2)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        bytes4 selector = hook.beforeRemoveLiquidity(
            user,
            poolKey,
            params,
            ""
        );
        
        assertEq(selector, BaseHook.beforeRemoveLiquidity.selector);
    }

    function test_AfterRemoveLiquidity_UpdatesLiquidityTracking() public {
        _configurePoolWithLST();
        _addLiquidityPosition(user);
        
        uint128 removeAmount = LIQUIDITY / 2;
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: -int256(uint256(removeAmount)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        (bytes4 selector, BalanceDelta delta) = hook.afterRemoveLiquidity(
            user,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        assertEq(selector, BaseHook.afterRemoveLiquidity.selector);
        assertEq(BalanceDelta.unwrap(delta), 0);
        
        // Check liquidity tracking updated
        assertEq(hook.userLiquidity(poolId, user), LIQUIDITY - removeAmount);
        assertEq(hook.totalLiquidity(poolId), LIQUIDITY - removeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        POSITION HEALTH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetPositionHealth_ValidPosition() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        // Advance time to ensure timeSinceLastAdjustment > 0
        vm.warp(block.timestamp + 3600); // 1 hour later
        
        // Set some yield drift
        mockAVS.setRequiredAdjustment(TOKEN1, 75);
        
        (
            uint256 currentYieldDrift,
            bool needsAdjustment,
            uint256 potentialILPrevention,
            uint256 timeSinceLastAdjustment
        ) = hook.getPositionHealth(positionId);
        
        assertEq(currentYieldDrift, 75);
        assertTrue(needsAdjustment); // 75 > 50 (threshold)
        assertGt(potentialILPrevention, 0);
        assertGt(timeSinceLastAdjustment, 0);
    }

    function test_GetPositionHealth_InvalidPosition() public {
        bytes32 fakePositionId = keccak256("fake");
        
        vm.expectRevert("YieldSync: position not found");
        hook.getPositionHealth(fakePositionId);
    }

    /*//////////////////////////////////////////////////////////////
                        MANUAL ADJUSTMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ManuallyAdjustPosition_Success() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        // Set required adjustment above threshold
        mockAVS.setRequiredAdjustment(TOKEN1, 100);
        
        // Wait for cooldown
        vm.warp(block.timestamp + hook.ADJUSTMENT_COOLDOWN() + 1);
        
        vm.expectEmit(true, true, false, false);
        emit PositionAdjusted(positionId, user, TICK_LOWER, TICK_UPPER, 0, 0, 100, 0);
        
        vm.prank(user);
        hook.manuallyAdjustPosition(positionId);
        
        // Check position was updated
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.accumulatedYieldBPS, 100);
        assertEq(position.lastYieldAdjustment, block.timestamp);
    }

    function test_ManuallyAdjustPosition_OnlyOwner() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        vm.prank(user2);
        vm.expectRevert("YieldSync: not position owner");
        hook.manuallyAdjustPosition(positionId);
    }

    function test_ManuallyAdjustPosition_InvalidPosition() public {
        bytes32 fakePositionId = keccak256("fake");
        
        vm.expectRevert("YieldSync: position not found");
        hook.manuallyAdjustPosition(fakePositionId);
    }

    /*//////////////////////////////////////////////////////////////
                        AUTO ADJUSTMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetAutoAdjustment_EnableDisable() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        // Initially enabled
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertTrue(position.autoAdjustEnabled);
        
        // Disable
        vm.prank(user);
        hook.setAutoAdjustment(positionId, false);
        
        position = hook.positions(positionId);
        assertFalse(position.autoAdjustEnabled);
        
        // Re-enable
        vm.prank(user);
        hook.setAutoAdjustment(positionId, true);
        
        position = hook.positions(positionId);
        assertTrue(position.autoAdjustEnabled);
    }

    function test_SetAutoAdjustment_OnlyOwner() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        vm.prank(user2);
        vm.expectRevert("YieldSync: not position owner");
        hook.setAutoAdjustment(positionId, false);
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSABLE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Pause_OnlyOwner() public {
        hook.pause();
        assertTrue(hook.paused());
    }

    function test_Pause_NonOwnerReverts() public {
        vm.prank(user);
        vm.expectRevert();
        hook.pause();
    }

    function test_Unpause_OnlyOwner() public {
        hook.pause();
        hook.unpause();
        assertFalse(hook.paused());
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constants_Values() public {
        assertEq(hook.MIN_ADJUSTMENT_THRESHOLD(), 10);
        assertEq(hook.MAX_ADJUSTMENT_THRESHOLD(), 500);
        assertEq(hook.ADJUSTMENT_COOLDOWN(), 21600); // 6 hours
        assertEq(hook.BASIS_POINTS(), 10000);
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

    function _addLiquidityPosition(address positionOwner) internal returns (bytes32 positionId) {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(
            positionOwner,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        return _getPositionId(positionOwner, poolId, TICK_LOWER, TICK_UPPER);
    }

    function _getPositionId(
        address posOwner,
        PoolId _poolId,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(posOwner, _poolId, tickLower, tickUpper));
    }

    /*//////////////////////////////////////////////////////////////
                         ADDITIONAL UNIT TESTS (50)
    //////////////////////////////////////////////////////////////*/

    function test_ConfigurePool_EmptyLSTToken() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: address(0),
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 100,
            autoAdjustmentEnabled: true
        });
        
        vm.expectRevert("YieldSync: invalid LST token");
        hook.configurePool(poolId, config);
    }

    function test_ConfigurePool_SameLSTAndPairedToken() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN1, // Same as LST token
            isLSTToken0: false,
            adjustmentThresholdBPS: 100,
            autoAdjustmentEnabled: true
        });
        
        hook.configurePool(poolId, config);
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.pairedToken, TOKEN1);
    }

    function test_ConfigurePool_IsLSTToken0True() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN0,
            pairedToken: TOKEN1,
            isLSTToken0: true,
            adjustmentThresholdBPS: 100,
            autoAdjustmentEnabled: true
        });
        
        hook.configurePool(poolId, config);
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertTrue(storedConfig.isLSTToken0);
    }

    function test_ConfigurePool_AutoAdjustmentDisabled() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 100,
            autoAdjustmentEnabled: false
        });
        
        hook.configurePool(poolId, config);
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertFalse(storedConfig.autoAdjustmentEnabled);
    }

    function test_AfterAddLiquidity_ZeroLiquidity() public {
        _configurePoolWithLST();
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: 0,
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
        
        // No position should be registered
        bytes32 positionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.owner, address(0));
    }

    function test_AfterAddLiquidity_MultiplePositionsSameUser() public {
        _configurePoolWithLST();
        
        // Add first position
        _addLiquidityPosition(user);
        
        // Add second position with different tick range
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER + 240,
            tickUpper: TICK_UPPER + 240,
            liquidityDelta: int256(uint256(LIQUIDITY)),
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
        
        // Check both positions exist
        bytes32 positionId1 = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        bytes32 positionId2 = _getPositionId(user, poolId, TICK_LOWER + 240, TICK_UPPER + 240);
        
        PositionAdjustment.PositionData memory position1 = hook.positions(positionId1);
        PositionAdjustment.PositionData memory position2 = hook.positions(positionId2);
        
        assertEq(position1.owner, user);
        assertEq(position2.owner, user);
        assertEq(hook.userLiquidity(poolId, user), LIQUIDITY * 2);
        assertEq(hook.totalLiquidity(poolId), LIQUIDITY * 2);
    }

    function test_AfterAddLiquidity_DifferentUsers() public {
        _configurePoolWithLST();
        
        address anotherUser = makeAddr("user2");
        
        // Add position for user1
        _addLiquidityPosition(user);
        
        // Add position for anotherUser
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(
            anotherUser,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        assertEq(hook.userLiquidity(poolId, user), LIQUIDITY);
        assertEq(hook.userLiquidity(poolId, anotherUser), LIQUIDITY);
        assertEq(hook.totalLiquidity(poolId), LIQUIDITY * 2);
    }

    function test_BeforeRemoveLiquidity_NoAdjustmentNeeded() public {
        _configurePoolWithLST();
        _addLiquidityPosition(user);
        
        // Set low yield drift (below threshold)
        mockAVS.setRequiredAdjustment(TOKEN1, 25); // Below 50 BPS threshold
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: -int256(uint256(LIQUIDITY/2)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        bytes4 selector = hook.beforeRemoveLiquidity(
            user,
            poolKey,
            params,
            ""
        );
        
        assertEq(selector, BaseHook.beforeRemoveLiquidity.selector);
    }

    function test_BeforeRemoveLiquidity_AutoAdjustmentDisabled() public {
        _configurePoolWithLST();
        
        // Configure pool with auto-adjustment disabled
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 50,
            autoAdjustmentEnabled: false
        });
        hook.configurePool(poolId, config);
        
        _addLiquidityPosition(user);
        mockAVS.setRequiredAdjustment(TOKEN1, 100);
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: -int256(uint256(LIQUIDITY/2)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        bytes4 selector = hook.beforeRemoveLiquidity(
            user,
            poolKey,
            params,
            ""
        );
        
        assertEq(selector, BaseHook.beforeRemoveLiquidity.selector);
    }

    function test_AfterRemoveLiquidity_FullRemoval() public {
        _configurePoolWithLST();
        _addLiquidityPosition(user);
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: -int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterRemoveLiquidity(
            user,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        assertEq(hook.userLiquidity(poolId, user), 0);
        assertEq(hook.totalLiquidity(poolId), 0);
    }

    function test_AfterRemoveLiquidity_PositiveLiquidityDelta() public {
        _configurePoolWithLST();
        _addLiquidityPosition(user);
        
        // Positive liquidity delta should not affect tracking
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(LIQUIDITY)), // Positive
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterRemoveLiquidity(
            user,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        // Should remain unchanged
        assertEq(hook.userLiquidity(poolId, user), LIQUIDITY);
        assertEq(hook.totalLiquidity(poolId), LIQUIDITY);
    }

    function test_ManuallyAdjustPosition_NoYieldAdjustmentNeeded() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        // Set yield below threshold
        mockAVS.setRequiredAdjustment(TOKEN1, 25);
        
        vm.prank(user);
        hook.manuallyAdjustPosition(positionId);
        
        // Position should remain unchanged
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.tickLower, TICK_LOWER);
        assertEq(position.tickUpper, TICK_UPPER);
    }

    function test_ManuallyAdjustPosition_WithinCooldownPeriod() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        // Set yield above threshold
        mockAVS.setRequiredAdjustment(TOKEN1, 100);
        
        // Try to adjust immediately (within cooldown)
        vm.prank(user);
        hook.manuallyAdjustPosition(positionId);
        
        // Position should remain unchanged due to cooldown
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.tickLower, TICK_LOWER);
        assertEq(position.tickUpper, TICK_UPPER);
    }

    function test_ManuallyAdjustPosition_SuccessfulAdjustment() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        // Advance time beyond cooldown
        vm.warp(block.timestamp + hook.ADJUSTMENT_COOLDOWN() + 1);
        
        // Set yield above threshold
        mockAVS.setRequiredAdjustment(TOKEN1, 100);
        
        vm.expectEmit(true, true, false, false);
        emit PositionAdjusted(positionId, user, TICK_LOWER, TICK_UPPER, 0, 0, 100, 0);
        
        vm.prank(user);
        hook.manuallyAdjustPosition(positionId);
    }

    function test_SetAutoAdjustment_NonExistentPosition() public {
        bytes32 fakePositionId = keccak256("fake");
        
        vm.expectRevert("YieldSync: position not found");
        vm.prank(user);
        hook.setAutoAdjustment(fakePositionId, true);
    }

    function test_SetAutoAdjustment_NonOwner() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        address nonOwner = makeAddr("nonOwner");
        vm.expectRevert("YieldSync: not position owner");
        vm.prank(nonOwner);
        hook.setAutoAdjustment(positionId, false);
    }

    function test_GetPositionHealth_ZeroYieldDrift() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        vm.warp(block.timestamp + 3600);
        mockAVS.setRequiredAdjustment(TOKEN1, 0);
        
        (
            uint256 currentYieldDrift,
            bool needsAdjustment,
            uint256 potentialILPrevention,
            uint256 timeSinceLastAdjustment
        ) = hook.getPositionHealth(positionId);
        
        assertEq(currentYieldDrift, 0);
        assertFalse(needsAdjustment);
        assertEq(potentialILPrevention, 0);
        assertGt(timeSinceLastAdjustment, 0);
    }

    function test_GetPositionHealth_ExactThreshold() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        vm.warp(block.timestamp + 3600);
        mockAVS.setRequiredAdjustment(TOKEN1, 50); // Exact threshold
        
        (, bool needsAdjustment, , ) = hook.getPositionHealth(positionId);
        assertTrue(needsAdjustment);
    }

    function test_Pause_FunctionalityWhenPaused() public {
        hook.pause();
        
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        // Pausing doesn't affect these functions since they don't have whenNotPaused modifier
        vm.prank(user);
        hook.setAutoAdjustment(positionId, false);
        
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertFalse(position.autoAdjustEnabled);
    }

    function test_Unpause_NonOwnerReverts() public {
        hook.pause();
        
        address nonOwner = makeAddr("nonOwner");
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        vm.prank(nonOwner);
        hook.unpause();
    }

    function test_Constants_Immutability() public {
        // Test that constants have expected values
        assertEq(hook.MIN_ADJUSTMENT_THRESHOLD(), 10);
        assertEq(hook.MAX_ADJUSTMENT_THRESHOLD(), 500);
        assertEq(hook.ADJUSTMENT_COOLDOWN(), 21600);
        assertEq(hook.BASIS_POINTS(), 10000);
    }

    function test_YieldSyncAVS_Immutability() public {
        assertEq(address(hook.yieldSyncAVS()), address(mockAVS));
    }

    function test_TotalILPrevented_InitiallyZero() public {
        assertEq(hook.totalILPrevented(user), 0);
        assertEq(hook.totalILPrevented(makeAddr("randomUser")), 0);
    }

    function test_PoolConfigs_InitiallyEmpty() public {
        IYieldSyncHook.LSTConfig memory config = hook.poolConfigs(poolId);
        assertEq(config.lstToken, address(0));
        assertEq(config.pairedToken, address(0));
        assertFalse(config.isLSTToken0);
        assertEq(config.adjustmentThresholdBPS, 0);
        assertFalse(config.autoAdjustmentEnabled);
    }

    function test_UserLiquidity_InitiallyZero() public {
        assertEq(hook.userLiquidity(poolId, user), 0);
        assertEq(hook.userLiquidity(poolId, makeAddr("randomUser")), 0);
    }

    function test_TotalLiquidity_InitiallyZero() public {
        assertEq(hook.totalLiquidity(poolId), 0);
    }

    function test_GetHookPermissions_Consistency() public {
        Hooks.Permissions memory perms1 = hook.getHookPermissions();
        Hooks.Permissions memory perms2 = hook.getHookPermissions();
        
        assertEq(perms1.beforeInitialize, perms2.beforeInitialize);
        assertEq(perms1.afterInitialize, perms2.afterInitialize);
        assertEq(perms1.beforeAddLiquidity, perms2.beforeAddLiquidity);
        assertEq(perms1.afterAddLiquidity, perms2.afterAddLiquidity);
    }

    function test_AfterInitialize_DifferentPoolKeys() public {
        // Test with different pool configurations
        PoolKey memory poolKey2 = PoolKey({
            currency0: Currency.wrap(TOKEN0),
            currency1: Currency.wrap(makeAddr("differentToken")),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        
        vm.prank(address(poolManager));
        bytes4 selector = hook.afterInitialize(
            address(0),
            poolKey2,
            0,
            0,
            ""
        );
        
        assertEq(selector, BaseHook.afterInitialize.selector);
    }

    function test_ConfigurePool_OverwriteExistingConfig() public {
        _configurePoolWithLST();
        
        IYieldSyncHook.LSTConfig memory newConfig = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN0, // Different LST token
            pairedToken: TOKEN1,
            isLSTToken0: true,
            adjustmentThresholdBPS: 200,
            autoAdjustmentEnabled: false
        });
        
        hook.configurePool(poolId, newConfig);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.lstToken, TOKEN0);
        assertEq(storedConfig.adjustmentThresholdBPS, 200);
        assertFalse(storedConfig.autoAdjustmentEnabled);
    }

    function test_AfterAddLiquidity_LargeTickRange() public {
        _configurePoolWithLST();
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -887272, // Max tick
            tickUpper: 887272,  // Max tick
            liquidityDelta: int256(uint256(LIQUIDITY)),
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
        
        bytes32 positionId = _getPositionId(user, poolId, -887272, 887272);
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.tickLower, -887272);
        assertEq(position.tickUpper, 887272);
    }

    function test_AfterAddLiquidity_MinimumLiquidity() public {
        _configurePoolWithLST();
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: 1, // Minimum positive liquidity
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
        assertEq(position.liquidity, 1);
    }

    function test_AfterRemoveLiquidity_ExcessiveRemoval() public {
        _configurePoolWithLST();
        _addLiquidityPosition(user);
        
        // Test shows that excessive removal causes underflow - this is expected Solidity behavior
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: -int256(uint256(LIQUIDITY * 2)), // More than user has
            salt: bytes32(0)
        });
        
        // This should revert due to underflow protection in Solidity
        vm.expectRevert();
        vm.prank(address(poolManager));
        hook.afterRemoveLiquidity(
            user,
            poolKey,
            params,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
    }

    function test_PositionId_Deterministic() public {
        bytes32 positionId1 = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        bytes32 positionId2 = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        
        assertEq(positionId1, positionId2);
    }

    function test_MultiplePoolConfigurations() public {
        // Configure first pool
        _configurePoolWithLST();
        
        // Create second pool
        PoolKey memory poolKey2 = PoolKey({
            currency0: Currency.wrap(makeAddr("token2")),
            currency1: Currency.wrap(makeAddr("token3")),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        PoolId poolId2 = poolKey2.toId();
        
        IYieldSyncHook.LSTConfig memory config2 = IYieldSyncHook.LSTConfig({
            lstToken: makeAddr("token3"),
            pairedToken: makeAddr("token2"),
            isLSTToken0: false,
            adjustmentThresholdBPS: 100,
            autoAdjustmentEnabled: true
        });
        
        hook.configurePool(poolId2, config2);
        
        // Verify both pools are configured independently
        IYieldSyncHook.LSTConfig memory storedConfig1 = hook.poolConfigs(poolId);
        IYieldSyncHook.LSTConfig memory storedConfig2 = hook.poolConfigs(poolId2);
        
        assertEq(storedConfig1.lstToken, TOKEN1);
        assertEq(storedConfig2.lstToken, makeAddr("token3"));
        assertEq(storedConfig1.adjustmentThresholdBPS, 50);
        assertEq(storedConfig2.adjustmentThresholdBPS, 100);
    }

    function test_GetPositionHealth_HighYieldDrift() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        vm.warp(block.timestamp + 3600);
        mockAVS.setRequiredAdjustment(TOKEN1, 1000); // Very high yield
        
        (
            uint256 currentYieldDrift,
            bool needsAdjustment,
            uint256 potentialILPrevention,
            
        ) = hook.getPositionHealth(positionId);
        
        assertEq(currentYieldDrift, 1000);
        assertTrue(needsAdjustment);
        assertGt(potentialILPrevention, 0);
    }

    function test_AfterAddLiquidity_NegativeTicks() public {
        _configurePoolWithLST();
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -2400,
            tickUpper: -1200,
            liquidityDelta: int256(uint256(LIQUIDITY)),
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
        
        bytes32 positionId = _getPositionId(user, poolId, -2400, -1200);
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.tickLower, -2400);
        assertEq(position.tickUpper, -1200);
    }

    function test_ManuallyAdjustPosition_AutoAdjustDisabled() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        // Disable auto-adjustment
        vm.prank(user);
        hook.setAutoAdjustment(positionId, false);
        
        vm.warp(block.timestamp + hook.ADJUSTMENT_COOLDOWN() + 1);
        mockAVS.setRequiredAdjustment(TOKEN1, 100);
        
        // Manual adjustment should still work even if auto-adjustment is disabled
        vm.prank(user);
        hook.manuallyAdjustPosition(positionId);
        
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertFalse(position.autoAdjustEnabled); // Should remain disabled
    }

    function test_ConfigurePool_BoundaryThresholds() public {
        // Test minimum threshold
        IYieldSyncHook.LSTConfig memory configMin = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: hook.MIN_ADJUSTMENT_THRESHOLD(),
            autoAdjustmentEnabled: true
        });
        
        hook.configurePool(poolId, configMin);
        
        // Test maximum threshold
        IYieldSyncHook.LSTConfig memory configMax = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: hook.MAX_ADJUSTMENT_THRESHOLD(),
            autoAdjustmentEnabled: true
        });
        
        hook.configurePool(poolId, configMax);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.adjustmentThresholdBPS, hook.MAX_ADJUSTMENT_THRESHOLD());
    }

    function test_AfterAddLiquidity_MaxLiquidity() public {
        _configurePoolWithLST();
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(type(uint128).max)), // Max uint128
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
        assertEq(position.liquidity, type(uint128).max);
    }

    function test_GetPositionHealth_FreshPosition() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        // Don't advance time - fresh position
        mockAVS.setRequiredAdjustment(TOKEN1, 75);
        
        (
            uint256 currentYieldDrift,
            bool needsAdjustment,
            uint256 potentialILPrevention,
            uint256 timeSinceLastAdjustment
        ) = hook.getPositionHealth(positionId);
        
        assertEq(currentYieldDrift, 75);
        assertTrue(needsAdjustment);
        assertGt(potentialILPrevention, 0);
        assertEq(timeSinceLastAdjustment, 0); // Fresh position
    }

    function test_PositionData_Completeness() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        
        // Verify all fields are properly set
        assertEq(position.owner, user);
        assertEq(PoolId.unwrap(position.poolId), PoolId.unwrap(poolId));
        assertEq(position.tickLower, TICK_LOWER);
        assertEq(position.tickUpper, TICK_UPPER);
        assertEq(position.liquidity, LIQUIDITY);
        assertEq(position.lstToken, TOKEN1);
        assertGt(position.lastYieldAdjustment, 0);
        assertEq(position.accumulatedYieldBPS, 0);
        assertTrue(position.autoAdjustEnabled);
    }

    function test_EventEmission_PoolConfigured() public {
        vm.expectEmit(true, true, true, true);
        emit PoolConfigured(poolId, TOKEN1, TOKEN0, true);
        
        _configurePoolWithLST();
    }

    function test_EventEmission_PositionRegistered() public {
        _configurePoolWithLST();
        
        bytes32 expectedPositionId = _getPositionId(user, poolId, TICK_LOWER, TICK_UPPER);
        
        vm.expectEmit(true, true, true, true);
        emit PositionRegistered(expectedPositionId, user, TOKEN1, TICK_LOWER, TICK_UPPER, LIQUIDITY);
        
        _addLiquidityPosition(user);
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
        bytes32 positionId = _addLiquidityPosition(user);
        
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
    ) public {
        // Ensure different parameters create different position IDs
        vm.assume(owner1 != owner2 || tickLower1 != tickLower2 || tickUpper1 != tickUpper2);
        
        bytes32 positionId1 = _getPositionId(owner1, poolId, tickLower1, tickUpper1);
        bytes32 positionId2 = _getPositionId(owner2, poolId, tickLower2, tickUpper2);
        
        assertTrue(positionId1 != positionId2);
    }

    function testFuzz_AutoAdjustment_Toggle(bool initialState, bool newState) public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        
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

    function testFuzz_MultipleUsers_LiquidityTracking(
        address[5] memory users,
        uint128[5] memory liquidityAmounts
    ) public {
        _configurePoolWithLST();
        
        uint256 totalExpected = 0;
        
        // Ensure unique addresses
        for (uint256 i = 0; i < 5; i++) {
            vm.assume(users[i] != address(0) && users[i] != address(hook));
            for (uint256 j = i + 1; j < 5; j++) {
                vm.assume(users[i] != users[j]);
            }
        }
        
        for (uint256 i = 0; i < 5; i++) {
            liquidityAmounts[i] = uint128(bound(liquidityAmounts[i], 1e15, 1e23));
            
            ModifyLiquidityParams memory params = ModifyLiquidityParams({
                tickLower: TICK_LOWER + int24(int256(i * 60)), // Different tick ranges
                tickUpper: TICK_UPPER + int24(int256(i * 60)),
                liquidityDelta: int256(uint256(liquidityAmounts[i])),
                salt: bytes32(0)
            });
            
            vm.prank(address(poolManager));
            hook.afterAddLiquidity(
                users[i],
                poolKey,
                params,
                BalanceDeltaLibrary.ZERO_DELTA,
                BalanceDeltaLibrary.ZERO_DELTA,
                ""
            );
            
            totalExpected += liquidityAmounts[i];
            assertEq(hook.userLiquidity(poolId, users[i]), liquidityAmounts[i]);
        }
        
        assertEq(hook.totalLiquidity(poolId), totalExpected);
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
        bytes32 positionId = _addLiquidityPosition(user);
        
        // Manually set position liquidity for testing
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        
        mockAVS.setRequiredAdjustment(TOKEN1, yieldBPS);
        
        (, , uint256 potentialILPrevention, ) = hook.getPositionHealth(positionId);
        
        // IL prevention should increase with both liquidity and yield
        assertGt(potentialILPrevention, 0);
        
        // Test with higher yield
        mockAVS.setRequiredAdjustment(TOKEN1, yieldBPS * 2);
        (, , uint256 higherILPrevention, ) = hook.getPositionHealth(positionId);
        
        assertGt(higherILPrevention, potentialILPrevention);
    }

    /*//////////////////////////////////////////////////////////////
                    SUCCESS & FAILURE FLOWS + ENHANCED FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // SUCCESS FLOWS (Happy Paths)
    
    function test_SuccessFlow_CompletePositionLifecycle() public {
        // 1. Configure pool with LST
        _configurePoolWithLST();
        
        // 2. Add liquidity position
        bytes32 positionId = _addLiquidityPosition(user);
        
        // 3. Enable auto-adjustment
        vm.prank(user);
        hook.setAutoAdjustment(positionId, true);
        
        // 4. Check position health
        vm.warp(block.timestamp + 3600);
        mockAVS.setRequiredAdjustment(TOKEN1, 100);
        
        (uint256 yieldDrift, bool needsAdjustment, uint256 ilPrevention, uint256 timeSince) = hook.getPositionHealth(positionId);
        assertTrue(needsAdjustment);
        assertGt(ilPrevention, 0);
        assertGt(timeSince, 0);
        
        // 5. Manual adjustment
        vm.warp(block.timestamp + hook.ADJUSTMENT_COOLDOWN() + 1);
        vm.prank(user);
        hook.manuallyAdjustPosition(positionId);
        
        // 6. Remove liquidity partially
        ModifyLiquidityParams memory removeParams = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: -int256(uint256(LIQUIDITY/2)),
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
        
        assertEq(hook.userLiquidity(poolId, user), LIQUIDITY/2);
        assertEq(hook.totalLiquidity(poolId), LIQUIDITY/2);
    }

    function test_SuccessFlow_MultipleUsersMultiplePools() public {
        // Setup multiple pools and users
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        
        // Pool 1: DAI/rETH
        _configurePoolWithLST();
        
        // Pool 2: USDC/stETH  
        PoolKey memory poolKey2 = PoolKey({
            currency0: Currency.wrap(makeAddr("USDC")),
            currency1: Currency.wrap(makeAddr("stETH")),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        PoolId poolId2 = poolKey2.toId();
        
        IYieldSyncHook.LSTConfig memory config2 = IYieldSyncHook.LSTConfig({
            lstToken: makeAddr("stETH"),
            pairedToken: makeAddr("USDC"),
            isLSTToken0: false,
            adjustmentThresholdBPS: 75,
            autoAdjustmentEnabled: true
        });
        hook.configurePool(poolId2, config2);
        
        // User1: Add to pool1
        ModifyLiquidityParams memory params1 = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(LIQUIDITY)),
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user1, poolKey, params1, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        // User2: Add to pool2
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user2, poolKey2, params1, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        // User3: Add to both pools
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user3, poolKey, params1, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(user3, poolKey2, params1, BalanceDeltaLibrary.ZERO_DELTA, BalanceDeltaLibrary.ZERO_DELTA, "");
        
        // Verify independent tracking
        assertEq(hook.totalLiquidity(poolId), LIQUIDITY * 2); // user1 + user3
        assertEq(hook.totalLiquidity(poolId2), LIQUIDITY * 2); // user2 + user3
        assertEq(hook.userLiquidity(poolId, user1), LIQUIDITY);
        assertEq(hook.userLiquidity(poolId2, user2), LIQUIDITY);
        assertEq(hook.userLiquidity(poolId, user3), LIQUIDITY);
        assertEq(hook.userLiquidity(poolId2, user3), LIQUIDITY);
    }

    // FAILURE FLOWS (Error Conditions)
    
    function test_FailureFlow_UnauthorizedAccess() public {
        _configurePoolWithLST();
        bytes32 positionId = _addLiquidityPosition(user);
        address unauthorized = makeAddr("unauthorized");
        
        // Unauthorized position adjustment
        vm.expectRevert("YieldSync: not position owner");
        vm.prank(unauthorized);
        hook.manuallyAdjustPosition(positionId);
        
        // Unauthorized auto-adjustment toggle
        vm.expectRevert("YieldSync: not position owner");
        vm.prank(unauthorized);
        hook.setAutoAdjustment(positionId, false);
        
        // Unauthorized owner actions
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        vm.prank(unauthorized);
        hook.pause();
        
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        vm.prank(unauthorized);
        hook.configurePool(poolId, IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 100,
            autoAdjustmentEnabled: true
        }));
    }

    function test_FailureFlow_InvalidConfigurations() public {
        // Invalid LST token
        vm.expectRevert("YieldSync: invalid LST token");
        hook.configurePool(poolId, IYieldSyncHook.LSTConfig({
            lstToken: address(0),
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 100,
            autoAdjustmentEnabled: true
        }));
    }

    function test_FailureFlow_ThresholdTooLow() public {
        // Threshold too low
        uint256 minThreshold = hook.MIN_ADJUSTMENT_THRESHOLD();
        vm.expectRevert("YieldSync: threshold too low");
        hook.configurePool(poolId, IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: minThreshold - 1,
            autoAdjustmentEnabled: true
        }));
    }

    function test_FailureFlow_ThresholdTooHigh() public {
        // Threshold too high
        uint256 maxThreshold = hook.MAX_ADJUSTMENT_THRESHOLD();
        vm.expectRevert("YieldSync: threshold too high");
        hook.configurePool(poolId, IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: maxThreshold + 1,
            autoAdjustmentEnabled: true
        }));
    }

    function test_FailureFlow_NonexistentPositions() public {
        bytes32 fakePositionId = keccak256("nonexistent");
        
        // Position health check
        vm.expectRevert("YieldSync: position not found");
        hook.getPositionHealth(fakePositionId);
        
        // Manual adjustment
        vm.expectRevert("YieldSync: position not found");
        vm.prank(user);
        hook.manuallyAdjustPosition(fakePositionId);
        
        // Auto-adjustment toggle
        vm.expectRevert("YieldSync: position not found");
        vm.prank(user);
        hook.setAutoAdjustment(fakePositionId, true);
    }

    function test_FailureFlow_BoundaryConditions() public {
        _configurePoolWithLST();
        
        // Test with extreme tick values
        ModifyLiquidityParams memory extremeParams = ModifyLiquidityParams({
            tickLower: -887272,
            tickUpper: 887272,
            liquidityDelta: 1, // Minimum liquidity
            salt: bytes32(0)
        });
        
        vm.prank(address(poolManager));
        hook.afterAddLiquidity(
            user,
            poolKey,
            extremeParams,
            BalanceDeltaLibrary.ZERO_DELTA,
            BalanceDeltaLibrary.ZERO_DELTA,
            ""
        );
        
        bytes32 positionId = _getPositionId(user, poolId, -887272, 887272);
        PositionAdjustment.PositionData memory position = hook.positions(positionId);
        assertEq(position.liquidity, 1);
        assertEq(position.tickLower, -887272);
        assertEq(position.tickUpper, 887272);
    }

    // ENHANCED FUZZ TESTS
    
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

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PoolConfigured(
        PoolId indexed poolId,
        address indexed lstToken,
        address indexed pairedToken,
        bool autoAdjustmentEnabled
    );

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
}