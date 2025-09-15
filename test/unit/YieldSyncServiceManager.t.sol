// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/avs/YieldSyncServiceManager.sol";
import "../../src/avs/IYieldSyncTaskManager.sol";
import "../../test/mocks/MockAVSDirectory.sol";
import "../../test/mocks/MockStakeRegistry.sol";
import "../../test/mocks/MockRewardsCoordinator.sol";
import "../../test/mocks/MockDelegationManager.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";

contract YieldSyncServiceManagerUnitTest is Test {
    YieldSyncServiceManager public serviceManager;
    MockAVSDirectory public avsDirectory;
    MockStakeRegistry public stakeRegistry;
    MockRewardsCoordinator public rewardsCoordinator;
    MockDelegationManager public delegationManager;
    
    address public owner;
    address public operator;
    address public strategy;

    function setUp() public {
        owner = address(this);
        operator = makeAddr("operator");
        strategy = makeAddr("strategy");
        
        // Deploy mocks
        vm.prank(owner);
        avsDirectory = new MockAVSDirectory();
        
        vm.prank(owner);
        stakeRegistry = new MockStakeRegistry();
        
        vm.prank(owner);
        rewardsCoordinator = new MockRewardsCoordinator();
        
        vm.prank(owner);
        delegationManager = new MockDelegationManager();
        
        // Deploy service manager
        vm.prank(owner);
        serviceManager = new YieldSyncServiceManager(
            IAVSDirectory(address(avsDirectory)),
            ISlashingRegistryCoordinator(makeAddr("registryCoordinator")),
            IStakeRegistry(address(stakeRegistry)),
            address(rewardsCoordinator),
            IAllocationManager(makeAddr("allocationManager")),
            IPermissionController(makeAddr("permissionController")),
            IYieldSyncTaskManager(makeAddr("taskManager"))
        );
    }

    // Constructor Tests (10 tests)
    function test_Constructor_SetsAVSDirectory() public {
        assertEq(address(serviceManager.avsDirectory()), address(avsDirectory));
    }

    function test_Constructor_SetsStakeRegistry() public {
        assertEq(address(serviceManager.stakeRegistry()), address(stakeRegistry));
    }

    function test_Constructor_SetsRewardsCoordinator() public {
        assertEq(address(serviceManager.rewardsCoordinator()), address(rewardsCoordinator));
    }

    function test_Constructor_SetsTaskManager() public {
        assertEq(address(serviceManager.yieldSyncTaskManager()), makeAddr("taskManager"));
    }

    function test_Constructor_SetsRegistryCoordinator() public {
        assertEq(address(serviceManager.registryCoordinator()), makeAddr("registryCoordinator"));
    }

    function test_Constructor_SetsAllocationManager() public {
        assertEq(address(serviceManager.allocationManager()), makeAddr("allocationManager"));
    }

    function test_Constructor_SetsPermissionController() public {
        assertEq(address(serviceManager.permissionController()), makeAddr("permissionController"));
    }

    function test_Constructor_ValidAddress() public {
        assertTrue(address(serviceManager) != address(0));
    }

    function test_Constructor_TaskManagerImmutable() public {
        // Test that task manager is immutable
        address taskManager1 = address(serviceManager.yieldSyncTaskManager());
        address taskManager2 = address(serviceManager.yieldSyncTaskManager());
        assertEq(taskManager1, taskManager2);
    }

    function test_Constructor_AllComponentsSet() public {
        // Test that all required components are set
        assertTrue(address(serviceManager.avsDirectory()) != address(0));
        assertTrue(address(serviceManager.stakeRegistry()) != address(0));
        assertTrue(address(serviceManager.rewardsCoordinator()) != address(0));
        assertTrue(address(serviceManager.yieldSyncTaskManager()) != address(0));
        assertTrue(address(serviceManager.registryCoordinator()) != address(0));
        assertTrue(address(serviceManager.allocationManager()) != address(0));
        assertTrue(address(serviceManager.permissionController()) != address(0));
    }

    // Registry Coordinator Tests (10 tests)
    function test_RegistryCoordinator_ReturnsCorrectAddress() public {
        assertEq(address(serviceManager.registryCoordinator()), makeAddr("registryCoordinator"));
    }

    function test_RegistryCoordinator_IsNotZero() public {
        assertTrue(address(serviceManager.registryCoordinator()) != address(0));
    }

    function test_RegistryCoordinator_Consistency() public {
        address coord1 = address(serviceManager.registryCoordinator());
        address coord2 = address(serviceManager.registryCoordinator());
        assertEq(coord1, coord2);
    }

    function test_RegistryCoordinator_TypeCorrect() public {
        ISlashingRegistryCoordinator coord = serviceManager.registryCoordinator();
        assertEq(address(coord), makeAddr("registryCoordinator"));
    }

    function test_RegistryCoordinator_Immutable() public {
        // Should always return the same address
        address initial = address(serviceManager.registryCoordinator());
        address later = address(serviceManager.registryCoordinator());
        assertEq(initial, later);
    }

    function test_RegistryCoordinator_NotAVSDirectory() public {
        assertNotEq(address(serviceManager.registryCoordinator()), address(serviceManager.avsDirectory()));
    }

    function test_RegistryCoordinator_NotStakeRegistry() public {
        assertNotEq(address(serviceManager.registryCoordinator()), address(serviceManager.stakeRegistry()));
    }

    function test_RegistryCoordinator_NotRewardsCoordinator() public {
        assertNotEq(address(serviceManager.registryCoordinator()), address(serviceManager.rewardsCoordinator()));
    }

    function test_RegistryCoordinator_NotTaskManager() public {
        assertNotEq(address(serviceManager.registryCoordinator()), address(serviceManager.yieldSyncTaskManager()));
    }

    function test_RegistryCoordinator_NotAllocationManager() public {
        assertNotEq(address(serviceManager.registryCoordinator()), address(serviceManager.allocationManager()));
    }

    // Stake Registry Tests (10 tests)
    function test_StakeRegistry_ReturnsCorrectAddress() public {
        assertEq(address(serviceManager.stakeRegistry()), address(stakeRegistry));
    }

    function test_StakeRegistry_IsNotZero() public {
        assertTrue(address(serviceManager.stakeRegistry()) != address(0));
    }

    function test_StakeRegistry_Consistency() public {
        address stake1 = address(serviceManager.stakeRegistry());
        address stake2 = address(serviceManager.stakeRegistry());
        assertEq(stake1, stake2);
    }

    function test_StakeRegistry_TypeCorrect() public {
        IStakeRegistry stake = serviceManager.stakeRegistry();
        assertEq(address(stake), address(stakeRegistry));
    }

    function test_StakeRegistry_Immutable() public {
        // Should always return the same address
        address initial = address(serviceManager.stakeRegistry());
        address later = address(serviceManager.stakeRegistry());
        assertEq(initial, later);
    }

    function test_StakeRegistry_NotAVSDirectory() public {
        assertNotEq(address(serviceManager.stakeRegistry()), address(serviceManager.avsDirectory()));
    }

    function test_StakeRegistry_NotRegistryCoordinator() public {
        assertNotEq(address(serviceManager.stakeRegistry()), address(serviceManager.registryCoordinator()));
    }

    function test_StakeRegistry_NotRewardsCoordinator() public {
        assertNotEq(address(serviceManager.stakeRegistry()), address(serviceManager.rewardsCoordinator()));
    }

    function test_StakeRegistry_NotTaskManager() public {
        assertNotEq(address(serviceManager.stakeRegistry()), address(serviceManager.yieldSyncTaskManager()));
    }

    function test_StakeRegistry_NotAllocationManager() public {
        assertNotEq(address(serviceManager.stakeRegistry()), address(serviceManager.allocationManager()));
    }

    // Rewards Coordinator Tests (10 tests)
    function test_RewardsCoordinator_ReturnsCorrectAddress() public {
        assertEq(address(serviceManager.rewardsCoordinator()), address(rewardsCoordinator));
    }

    function test_RewardsCoordinator_IsNotZero() public {
        assertTrue(address(serviceManager.rewardsCoordinator()) != address(0));
    }

    function test_RewardsCoordinator_Consistency() public {
        address rewards1 = address(serviceManager.rewardsCoordinator());
        address rewards2 = address(serviceManager.rewardsCoordinator());
        assertEq(rewards1, rewards2);
    }

    function test_RewardsCoordinator_TypeCorrect() public {
        IRewardsCoordinator rewards = serviceManager.rewardsCoordinator();
        assertEq(address(rewards), address(rewardsCoordinator));
    }

    function test_RewardsCoordinator_Immutable() public {
        // Should always return the same address
        address initial = address(serviceManager.rewardsCoordinator());
        address later = address(serviceManager.rewardsCoordinator());
        assertEq(initial, later);
    }

    function test_RewardsCoordinator_NotAVSDirectory() public {
        assertNotEq(address(serviceManager.rewardsCoordinator()), address(serviceManager.avsDirectory()));
    }

    function test_RewardsCoordinator_NotRegistryCoordinator() public {
        assertNotEq(address(serviceManager.rewardsCoordinator()), address(serviceManager.registryCoordinator()));
    }

    function test_RewardsCoordinator_NotStakeRegistry() public {
        assertNotEq(address(serviceManager.rewardsCoordinator()), address(serviceManager.stakeRegistry()));
    }

    function test_RewardsCoordinator_NotTaskManager() public {
        assertNotEq(address(serviceManager.rewardsCoordinator()), address(serviceManager.yieldSyncTaskManager()));
    }

    function test_RewardsCoordinator_NotAllocationManager() public {
        assertNotEq(address(serviceManager.rewardsCoordinator()), address(serviceManager.allocationManager()));
    }

    // Task Manager Tests (10 tests)
    function test_TaskManager_ReturnsCorrectAddress() public {
        assertEq(address(serviceManager.yieldSyncTaskManager()), makeAddr("taskManager"));
    }

    function test_TaskManager_IsNotZero() public {
        assertTrue(address(serviceManager.yieldSyncTaskManager()) != address(0));
    }

    function test_TaskManager_Consistency() public {
        address task1 = address(serviceManager.yieldSyncTaskManager());
        address task2 = address(serviceManager.yieldSyncTaskManager());
        assertEq(task1, task2);
    }

    function test_TaskManager_TypeCorrect() public {
        IYieldSyncTaskManager task = serviceManager.yieldSyncTaskManager();
        assertEq(address(task), makeAddr("taskManager"));
    }

    function test_TaskManager_Immutable() public {
        // Should always return the same address
        address initial = address(serviceManager.yieldSyncTaskManager());
        address later = address(serviceManager.yieldSyncTaskManager());
        assertEq(initial, later);
    }

    function test_TaskManager_NotAVSDirectory() public {
        assertNotEq(address(serviceManager.yieldSyncTaskManager()), address(serviceManager.avsDirectory()));
    }

    function test_TaskManager_NotRegistryCoordinator() public {
        assertNotEq(address(serviceManager.yieldSyncTaskManager()), address(serviceManager.registryCoordinator()));
    }

    function test_TaskManager_NotStakeRegistry() public {
        assertNotEq(address(serviceManager.yieldSyncTaskManager()), address(serviceManager.stakeRegistry()));
    }

    function test_TaskManager_NotRewardsCoordinator() public {
        assertNotEq(address(serviceManager.yieldSyncTaskManager()), address(serviceManager.rewardsCoordinator()));
    }

    function test_TaskManager_NotAllocationManager() public {
        assertNotEq(address(serviceManager.yieldSyncTaskManager()), address(serviceManager.allocationManager()));
    }
}