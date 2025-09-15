// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../src/hooks/YieldSyncHook.sol";
import {YieldSyncServiceManager} from "../../src/avs/YieldSyncServiceManager.sol";
import "../../src/avs/YieldSyncTaskManager.sol";
import "../../src/avs/LSTMonitors/LidoYieldMonitor.sol";

import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";

/**
 * @title YieldSyncIntegrationTest
 * @dev Integration tests for YieldSync Hook and AVS
 */
contract YieldSyncIntegrationTest is Test {
    using PoolIdLibrary for PoolKey;

    // Contracts
    YieldSyncHook public hook;
    YieldSyncServiceManager public serviceManager;
    YieldSyncTaskManager public taskManager;
    LidoYieldMonitor public lidoMonitor;
    
    // Mock contracts
    IPoolManager public poolManager;
    
    // Test addresses
    address public owner;
    address public user;
    address public operator;
    
    // Test data
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        operator = makeAddr("operator");
        
        // Deploy mock pool manager
        poolManager = IPoolManager(makeAddr("poolManager"));
        
        // Deploy LST monitor
        lidoMonitor = new LidoYieldMonitor();
        
        // Deploy task manager (simplified for testing)
        taskManager = new YieldSyncTaskManager(
            ISlashingRegistryCoordinator(makeAddr("slashingRegistryCoordinator")),
            IPauserRegistry(makeAddr("pauserRegistry")),
            100 // TASK_RESPONSE_WINDOW_BLOCK
        );
        
        // Deploy service manager (simplified for testing)
        serviceManager = new YieldSyncServiceManager(
            IAVSDirectory(makeAddr("avsDirectory")),
            ISlashingRegistryCoordinator(makeAddr("slashingRegistryCoordinator")),
            IStakeRegistry(makeAddr("stakeRegistry")),
            makeAddr("rewardsCoordinator"),
            IAllocationManager(makeAddr("allocationManager")),
            IPermissionController(makeAddr("permissionController")),
            IYieldSyncTaskManager(address(taskManager))
        );
        
        // Deploy hook
        hook = new YieldSyncHook(
            poolManager,
            IYieldSyncAVS(address(serviceManager))
        );
    }
    
    function testHookDeployment() public {
        assertEq(address(hook.poolManager()), address(poolManager));
        assertEq(address(hook.yieldSyncAVS()), address(serviceManager));
        assertEq(hook.owner(), owner);
    }
    
    function testHookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        assertFalse(permissions.beforeInitialize);
        assertTrue(permissions.afterInitialize);
        assertFalse(permissions.beforeAddLiquidity);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.afterRemoveLiquidity);
        assertFalse(permissions.beforeSwap);
        assertFalse(permissions.afterSwap);
    }
    
    function testLSTDetection() public {
        // Test LST detection in pool
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(STETH),
            currency1: Currency.wrap(WETH),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        // This would test the LST detection logic
        // In a real test, you'd call the hook's afterInitialize function
        console.log("LST detection test would go here");
    }
    
    function testPositionRegistration() public {
        // Test position registration
        bytes32 positionId = keccak256(abi.encodePacked(user, uint256(1), int24(-60), int24(60)));
        
        // This would test position registration
        // In a real test, you'd call the hook's afterAddLiquidity function
        console.log("Position registration test would go here");
    }
    
    function testYieldAdjustment() public {
        // Test yield adjustment
        bytes32 positionId = keccak256(abi.encodePacked(user, uint256(1), int24(-60), int24(60)));
        
        // This would test yield adjustment
        // In a real test, you'd call the hook's manuallyAdjustPosition function
        console.log("Yield adjustment test would go here");
    }
}
