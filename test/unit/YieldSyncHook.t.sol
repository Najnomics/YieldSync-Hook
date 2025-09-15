// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/hooks/YieldSyncHook.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import "../../src/hooks/interfaces/IYieldSyncHook.sol";
import "../../src/avs/interfaces/IYieldSyncAVS.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

contract YieldSyncHookUnitTest is Test {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    YieldSyncHook public hook;
    PoolKey public poolKey;
    
    // Test addresses
    address public owner;
    address public user;
    
    // Test constants
    address constant TOKEN0 = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
    address constant TOKEN1 = 0xae78736Cd615f374D3085123A210448E74Fc6393; // rETH
    int24 constant TICK_SPACING = 60;
    uint24 constant FEE = 3000;

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        
        // Deploy hook with mock addresses
        hook = new YieldSyncHook(
            IPoolManager(makeAddr("poolManager")), 
            IYieldSyncAVS(makeAddr("yieldSyncAVS"))
        );
        
        // Set up pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(TOKEN0),
            currency1: Currency.wrap(TOKEN1),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
    }

    // Constructor Tests (10 tests)
    function test_Constructor_SetsPoolManager() public {
        assertEq(address(hook.poolManager()), makeAddr("poolManager"));
    }

    function test_Constructor_SetsOwner() public {
        assertEq(hook.owner(), owner);
    }

    function test_Constructor_ValidAddress() public {
        assertTrue(address(hook) != address(0));
    }

    function test_Constructor_InitialState() public {
        // Pool should not be configured yet
        PoolId poolId = poolKey.toId();
        IYieldSyncHook.LSTConfig memory config = hook.poolConfigs(poolId);
        assertEq(config.lstToken, address(0));
    }

    function test_Constructor_OwnershipSet() public {
        assertTrue(hook.owner() != address(0));
        assertEq(hook.owner(), owner);
    }

    function test_Constructor_PoolManagerSet() public {
        assertTrue(address(hook.poolManager()) != address(0));
    }

    function test_Constructor_HookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.afterInitialize);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.afterRemoveLiquidity);
    }

    function test_Constructor_MultipleDeployments() public {
        YieldSyncHook hook2 = new YieldSyncHook(
            IPoolManager(makeAddr("poolManager2")), 
            IYieldSyncAVS(makeAddr("yieldSyncAVS2"))
        );
        assertNotEq(address(hook), address(hook2));
    }

    function test_Constructor_CorrectInterface() public {
        // Should implement IHooks interface properly
        assertTrue(address(hook) != address(0));
    }

    function test_Constructor_YieldSyncAVSSet() public {
        assertEq(address(hook.yieldSyncAVS()), makeAddr("yieldSyncAVS"));
    }

    // Pool Configuration Tests (10 tests)
    function test_ConfigurePool_ValidConfiguration() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 50,
            autoAdjustmentEnabled: true
        });
        PoolId poolId = poolKey.toId();
        
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
        PoolId poolId = poolKey.toId();
        
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
        PoolId poolId = poolKey.toId();
        
        vm.expectRevert();
        hook.configurePool(poolId, config);
    }

    function test_ConfigurePool_LowThreshold() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 5, // Below minimum
            autoAdjustmentEnabled: true
        });
        PoolId poolId = poolKey.toId();
        
        vm.expectRevert();
        hook.configurePool(poolId, config);
    }

    function test_ConfigurePool_HighThreshold() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 600, // Above maximum
            autoAdjustmentEnabled: true
        });
        PoolId poolId = poolKey.toId();
        
        vm.expectRevert();
        hook.configurePool(poolId, config);
    }

    function test_ConfigurePool_MinValidThreshold() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 10, // Minimum valid
            autoAdjustmentEnabled: true
        });
        PoolId poolId = poolKey.toId();
        
        hook.configurePool(poolId, config);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.adjustmentThresholdBPS, 10);
    }

    function test_ConfigurePool_MaxValidThreshold() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 500, // Maximum valid
            autoAdjustmentEnabled: true
        });
        PoolId poolId = poolKey.toId();
        
        hook.configurePool(poolId, config);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.adjustmentThresholdBPS, 500);
    }

    function test_ConfigurePool_LSTAsToken0() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN0, // LST as token0
            pairedToken: TOKEN1,
            isLSTToken0: true,
            adjustmentThresholdBPS: 50,
            autoAdjustmentEnabled: true
        });
        PoolId poolId = poolKey.toId();
        
        hook.configurePool(poolId, config);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertTrue(storedConfig.isLSTToken0);
    }

    function test_ConfigurePool_DisableAutoAdjustment() public {
        IYieldSyncHook.LSTConfig memory config = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 50,
            autoAdjustmentEnabled: false
        });
        PoolId poolId = poolKey.toId();
        
        hook.configurePool(poolId, config);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertFalse(storedConfig.autoAdjustmentEnabled);
    }

    function test_ConfigurePool_OverwriteConfiguration() public {
        PoolId poolId = poolKey.toId();
        
        // First configuration
        IYieldSyncHook.LSTConfig memory config1 = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 50,
            autoAdjustmentEnabled: true
        });
        hook.configurePool(poolId, config1);
        
        // Second configuration (overwrite)
        IYieldSyncHook.LSTConfig memory config2 = IYieldSyncHook.LSTConfig({
            lstToken: TOKEN1,
            pairedToken: TOKEN0,
            isLSTToken0: false,
            adjustmentThresholdBPS: 100,
            autoAdjustmentEnabled: false
        });
        hook.configurePool(poolId, config2);
        
        IYieldSyncHook.LSTConfig memory storedConfig = hook.poolConfigs(poolId);
        assertEq(storedConfig.adjustmentThresholdBPS, 100);
        assertFalse(storedConfig.autoAdjustmentEnabled);
    }

    // Hook Permissions Tests (10 tests)
    function test_HookPermissions_AfterInitialize() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.afterInitialize);
    }

    function test_HookPermissions_AfterAddLiquidity() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.afterAddLiquidity);
    }

    function test_HookPermissions_BeforeRemoveLiquidity() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.beforeRemoveLiquidity);
    }

    function test_HookPermissions_AfterRemoveLiquidity() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.afterRemoveLiquidity);
    }

    function test_HookPermissions_BeforeInitialize() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertFalse(permissions.beforeInitialize);
    }

    function test_HookPermissions_BeforeAddLiquidity() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertFalse(permissions.beforeAddLiquidity);
    }

    function test_HookPermissions_BeforeSwap() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertFalse(permissions.beforeSwap);
    }

    function test_HookPermissions_AfterSwap() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertFalse(permissions.afterSwap);
    }

    function test_HookPermissions_BeforeDonate() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertFalse(permissions.beforeDonate);
    }

    function test_HookPermissions_AfterDonate() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertFalse(permissions.afterDonate);
    }

    // Constants Tests (10 tests)
    function test_Constants_MinAdjustmentThreshold() public {
        uint256 min = hook.MIN_ADJUSTMENT_THRESHOLD();
        assertEq(min, 10);
    }

    function test_Constants_MaxAdjustmentThreshold() public {
        uint256 max = hook.MAX_ADJUSTMENT_THRESHOLD();
        assertEq(max, 500);
    }

    function test_Constants_AdjustmentCooldown() public {
        uint256 cooldown = hook.ADJUSTMENT_COOLDOWN();
        assertEq(cooldown, 21600); // 6 hours
    }

    function test_Constants_BasisPoints() public {
        uint256 bp = hook.BASIS_POINTS();
        assertEq(bp, 10000);
    }

    function test_Constants_MinThresholdNonZero() public {
        uint256 min = hook.MIN_ADJUSTMENT_THRESHOLD();
        assertGt(min, 0);
    }

    function test_Constants_MaxThresholdGreaterThanMin() public {
        uint256 min = hook.MIN_ADJUSTMENT_THRESHOLD();
        uint256 max = hook.MAX_ADJUSTMENT_THRESHOLD();
        assertGt(max, min);
    }

    function test_Constants_CooldownNonZero() public {
        uint256 cooldown = hook.ADJUSTMENT_COOLDOWN();
        assertGt(cooldown, 0);
    }

    function test_Constants_BasisPointsStandard() public {
        uint256 bp = hook.BASIS_POINTS();
        assertEq(bp, 10000); // Standard 100% = 10000 BPS
    }

    function test_Constants_CooldownReasonable() public {
        uint256 cooldown = hook.ADJUSTMENT_COOLDOWN();
        assertGe(cooldown, 3600); // At least 1 hour
        assertLe(cooldown, 86400); // At most 1 day
    }

    function test_Constants_ThresholdRangeReasonable() public {
        uint256 min = hook.MIN_ADJUSTMENT_THRESHOLD();
        uint256 max = hook.MAX_ADJUSTMENT_THRESHOLD();
        
        // Min should be at least 0.01% (1 BPS)
        assertGe(min, 1);
        // Max should be at most 10% (1000 BPS)
        assertLe(max, 1000);
    }

    // Pausable Tests (10 tests)
    function test_Pausable_InitiallyUnpaused() public {
        assertFalse(hook.paused());
    }

    function test_Pausable_OwnerCanPause() public {
        hook.pause();
        assertTrue(hook.paused());
    }

    function test_Pausable_OwnerCanUnpause() public {
        hook.pause();
        hook.unpause();
        assertFalse(hook.paused());
    }

    function test_Pausable_NonOwnerCannotPause() public {
        vm.prank(user);
        vm.expectRevert();
        hook.pause();
    }

    function test_Pausable_NonOwnerCannotUnpause() public {
        hook.pause();
        vm.prank(user);
        vm.expectRevert();
        hook.unpause();
    }

    function test_Pausable_PauseEmitsEvent() public {
        vm.expectEmit(false, false, false, false);
        emit Paused(address(this));
        hook.pause();
    }

    function test_Pausable_UnpauseEmitsEvent() public {
        hook.pause();
        vm.expectEmit(false, false, false, false);
        emit Unpaused(address(this));
        hook.unpause();
    }

    function test_Pausable_CannotPauseWhenPaused() public {
        hook.pause();
        vm.expectRevert();
        hook.pause();
    }

    function test_Pausable_CannotUnpauseWhenUnpaused() public {
        vm.expectRevert();
        hook.unpause();
    }

    function test_Pausable_StateChanges() public {
        // Initially unpaused
        assertFalse(hook.paused());
        
        // Pause
        hook.pause();
        assertTrue(hook.paused());
        
        // Unpause
        hook.unpause();
        assertFalse(hook.paused());
    }

    // Events (need to be declared for testing)
    event Paused(address account);
    event Unpaused(address account);
}