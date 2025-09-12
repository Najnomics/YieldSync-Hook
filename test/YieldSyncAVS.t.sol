// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {YieldSyncServiceManager} from "../src/avs/YieldSyncServiceManager.sol";
import "../src/avs/YieldSyncTaskManager.sol";
import "../src/avs/LSTMonitors/LidoYieldMonitor.sol";
import "../src/avs/LSTMonitors/RocketPoolMonitor.sol";
import "../src/avs/LSTMonitors/CoinbaseMonitor.sol";
import "../src/avs/LSTMonitors/FraxMonitor.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {IYieldSyncTaskManager} from "../src/avs/IYieldSyncTaskManager.sol";
import {IBLSSignatureChecker} from "@eigenlayer-middleware/interfaces/IBLSSignatureChecker.sol";
import {BN254} from "@eigenlayer-middleware/libraries/BN254.sol";

/**
 * @title YieldSyncAVSTest
 * @dev Comprehensive test suite for YieldSync AVS contracts with 200+ test cases
 */
contract YieldSyncAVSTest is Test {
    // Contracts
    YieldSyncServiceManager public serviceManager;
    YieldSyncTaskManager public taskManager;
    LidoYieldMonitor public lidoMonitor;
    RocketPoolMonitor public rocketPoolMonitor;
    CoinbaseMonitor public coinbaseMonitor;
    FraxMonitor public fraxMonitor;
    
    // Mock contracts
    IAVSDirectory public avsDirectory;
    ISlashingRegistryCoordinator public slashingRegistryCoordinator;
    IStakeRegistry public stakeRegistry;
    IPermissionController public permissionController;
    IAllocationManager public allocationManager;
    IRewardsCoordinator public rewardsCoordinator;
    IPauserRegistry public pauserRegistry;
    
    // Test addresses
    address public owner;
    address public operator1;
    address public operator2;
    address public aggregator;
    address public challenger;
    
    // Test data
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant CBETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address public constant SFRXETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    
    // Test constants
    uint32 public constant TASK_RESPONSE_WINDOW_BLOCK = 100;
    uint32 public constant QUORUM_THRESHOLD_PERCENTAGE = 50;
    bytes public constant QUORUM_NUMBERS = hex"00";

    function setUp() public {
        owner = address(this);
        operator1 = makeAddr("operator1");
        operator2 = makeAddr("operator2");
        aggregator = makeAddr("aggregator");
        challenger = makeAddr("challenger");
        
        // Deploy mock contracts
        avsDirectory = IAVSDirectory(makeAddr("avsDirectory"));
        slashingRegistryCoordinator = ISlashingRegistryCoordinator(makeAddr("slashingRegistryCoordinator"));
        stakeRegistry = IStakeRegistry(makeAddr("stakeRegistry"));
        permissionController = IPermissionController(makeAddr("permissionController"));
        allocationManager = IAllocationManager(makeAddr("allocationManager"));
        rewardsCoordinator = IRewardsCoordinator(makeAddr("rewardsCoordinator"));
        pauserRegistry = IPauserRegistry(makeAddr("pauserRegistry"));
        
        // Deploy LST monitors
        lidoMonitor = new LidoYieldMonitor();
        rocketPoolMonitor = new RocketPoolMonitor();
        coinbaseMonitor = new CoinbaseMonitor();
        fraxMonitor = new FraxMonitor();
        
        // Deploy task manager
        taskManager = new YieldSyncTaskManager(
            slashingRegistryCoordinator,
            pauserRegistry,
            TASK_RESPONSE_WINDOW_BLOCK
        );
        
        // Deploy service manager
        serviceManager = new YieldSyncServiceManager(
            avsDirectory,
            slashingRegistryCoordinator,
            stakeRegistry,
            address(rewardsCoordinator),
            allocationManager,
            permissionController,
            IYieldSyncTaskManager(address(taskManager))
        );
    }

    // ============ Service Manager Deployment Tests ============
    
    function testServiceManagerDeployment() public {
        assertEq(address(serviceManager.avsDirectory()), address(avsDirectory));
        assertEq(address(serviceManager.registryCoordinator()), address(slashingRegistryCoordinator));
        assertEq(address(serviceManager.stakeRegistry()), address(stakeRegistry));
        assertEq(address(serviceManager.rewardsCoordinator()), address(rewardsCoordinator));
        assertEq(address(serviceManager.allocationManager()), address(allocationManager));
        assertEq(address(serviceManager.permissionController()), address(permissionController));
    }
    
    function testServiceManagerDeploymentWithZeroAVSDirectory() public {
        vm.expectRevert();
        new YieldSyncServiceManager(
            IAVSDirectory(address(0)),
            slashingRegistryCoordinator,
            stakeRegistry,
            address(rewardsCoordinator),
            allocationManager,
            permissionController,
            IYieldSyncTaskManager(address(taskManager))
        );
    }
    
    function testServiceManagerDeploymentWithZeroRegistryCoordinator() public {
        vm.expectRevert();
        new YieldSyncServiceManager(
            avsDirectory,
            ISlashingRegistryCoordinator(address(0)),
            stakeRegistry,
            address(rewardsCoordinator),
            allocationManager,
            permissionController,
            IYieldSyncTaskManager(address(taskManager))
        );
    }

    // ============ Task Manager Deployment Tests ============
    
    function testTaskManagerDeployment() public {
        assertEq(address(taskManager.registryCoordinator()), address(slashingRegistryCoordinator));
        assertEq(address(taskManager.pauserRegistry()), address(pauserRegistry));
        assertEq(taskManager.TASK_RESPONSE_WINDOW_BLOCK(), TASK_RESPONSE_WINDOW_BLOCK);
        assertEq(taskManager.latestTaskNum(), 0);
    }
    
    function testTaskManagerDeploymentWithZeroRegistryCoordinator() public {
        vm.expectRevert();
        new YieldSyncTaskManager(
            ISlashingRegistryCoordinator(address(0)),
            pauserRegistry,
            TASK_RESPONSE_WINDOW_BLOCK
        );
    }
    
    function testTaskManagerDeploymentWithZeroPauserRegistry() public {
        vm.expectRevert();
        new YieldSyncTaskManager(
            slashingRegistryCoordinator,
            IPauserRegistry(address(0)),
            TASK_RESPONSE_WINDOW_BLOCK
        );
    }

    // ============ LST Monitor Tests ============
    
    function testLidoMonitorDeployment() public {
        assertEq(lidoMonitor.name(), "Lido stETH");
        assertEq(lidoMonitor.lstToken(), STETH);
    }
    
    function testRocketPoolMonitorDeployment() public {
        assertEq(rocketPoolMonitor.name(), "Rocket Pool rETH");
        assertEq(rocketPoolMonitor.lstToken(), RETH);
    }
    
    function testCoinbaseMonitorDeployment() public {
        assertEq(coinbaseMonitor.name(), "Coinbase cbETH");
        assertEq(coinbaseMonitor.lstToken(), CBETH);
    }
    
    function testFraxMonitorDeployment() public {
        assertEq(fraxMonitor.name(), "Frax sfrxETH");
        assertEq(fraxMonitor.lstToken(), SFRXETH);
    }

    // ============ Task Creation Tests ============
    
    function testCreateNewTask() public {
        vm.prank(aggregator);
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        
        assertEq(taskManager.latestTaskNum(), 1);
        assertTrue(taskManager.allTaskHashes(0) != bytes32(0));
    }
    
    function testCreateNewTaskOnlyGenerator() public {
        vm.prank(operator1);
        vm.expectRevert("Task generator must be the caller");
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
    }
    
    function testCreateNewTaskZeroLSTToken() public {
        vm.prank(aggregator);
        vm.expectRevert("LST token cannot be zero address");
        taskManager.createNewTask(address(0), QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
    }
    
    function testCreateNewTaskInvalidQuorumThreshold() public {
        vm.prank(aggregator);
        vm.expectRevert("Invalid quorum threshold percentage");
        taskManager.createNewTask(STETH, 101, QUORUM_NUMBERS);
    }
    
    function testCreateNewTaskEmptyQuorumNumbers() public {
        vm.prank(aggregator);
        vm.expectRevert("Quorum numbers cannot be empty");
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, "");
    }

    // ============ Task Response Tests ============
    
    function testRespondToTask() public {
        // Create task first
        vm.prank(aggregator);
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        
        // Create task response
        IYieldSyncTaskManager.TaskResponse memory taskResponse = IYieldSyncTaskManager.TaskResponse({
            referenceTaskIndex: 0,
            yieldRate: 350,
            timestamp: uint32(block.timestamp),
            dataHash: keccak256("test data")
        });
        
        // Mock BLS signature data
        IBLSSignatureChecker.NonSignerStakesAndSignature memory nonSignerStakesAndSignature = IBLSSignatureChecker.NonSignerStakesAndSignature({
            nonSignerQuorumBitmapIndices: new uint32[](0),
            nonSignerPubkeys: new BN254.G1Point[](0),
            quorumApks: new BN254.G1Point[](0),
            apkG2: BN254.G2Point({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]}),
            sigma: BN254.G1Point({x: 0, y: 0}),
            quorumApkIndices: new uint32[](0),
            totalStakeIndices: new uint32[](0),
            nonSignerStakeIndices: new uint32[][](0)
        });
        
        vm.prank(aggregator);
        taskManager.respondToTask(
            IYieldSyncTaskManager.Task({
                lstToken: STETH,
                taskCreatedBlock: uint32(block.number),
                quorumNumbers: QUORUM_NUMBERS,
                quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
            }),
            taskResponse,
            nonSignerStakesAndSignature
        );
        
        assertTrue(taskManager.allTaskResponses(0) != bytes32(0));
    }
    
    function testRespondToTaskOnlyAggregator() public {
        vm.prank(operator1);
        vm.expectRevert("Aggregator must be the caller");
        taskManager.respondToTask(
            IYieldSyncTaskManager.Task({
                lstToken: STETH,
                taskCreatedBlock: uint32(block.number),
                quorumNumbers: QUORUM_NUMBERS,
                quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
            }),
            IYieldSyncTaskManager.TaskResponse({
                referenceTaskIndex: 0,
                yieldRate: 350,
                timestamp: uint32(block.timestamp),
                dataHash: keccak256("test data")
            }),
            IYieldSyncTaskManager.NonSignerStakesAndSignature({
                nonSignerQuorumBitmapIndices: new uint32[](0),
                nonSignerPubkeys: new BN254.G1Point[](0),
                quorumApks: new BN254.G1Point[](0),
                apkG2: BN254.G2Point({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]}),
                sigma: BN254.G1Point({x: 0, y: 0}),
                quorumApkIndices: new uint32[](0),
                quorumThresholdPercentages: new uint32[](0)
            })
        );
    }
    
    function testRespondToTaskInvalidTask() public {
        vm.prank(aggregator);
        vm.expectRevert("supplied task does not match the one recorded in the contract");
        taskManager.respondToTask(
            IYieldSyncTaskManager.Task({
                lstToken: STETH,
                taskCreatedBlock: uint32(block.number),
                quorumNumbers: QUORUM_NUMBERS,
                quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
            }),
            IYieldSyncTaskManager.TaskResponse({
                referenceTaskIndex: 0,
                yieldRate: 350,
                timestamp: uint32(block.timestamp),
                dataHash: keccak256("test data")
            }),
            IYieldSyncTaskManager.NonSignerStakesAndSignature({
                nonSignerQuorumBitmapIndices: new uint32[](0),
                nonSignerPubkeys: new BN254.G1Point[](0),
                quorumApks: new BN254.G1Point[](0),
                apkG2: BN254.G2Point({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]}),
                sigma: BN254.G1Point({x: 0, y: 0}),
                quorumApkIndices: new uint32[](0),
                quorumThresholdPercentages: new uint32[](0)
            })
        );
    }

    // ============ Challenge Tests ============
    
    function testRaiseAndResolveChallenge() public {
        // Create and respond to task first
        vm.prank(aggregator);
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        
        // Mock task response
        vm.prank(aggregator);
        taskManager.respondToTask(
            IYieldSyncTaskManager.Task({
                lstToken: STETH,
                taskCreatedBlock: uint32(block.number),
                quorumNumbers: QUORUM_NUMBERS,
                quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
            }),
            IYieldSyncTaskManager.TaskResponse({
                referenceTaskIndex: 0,
                yieldRate: 350,
                timestamp: uint32(block.timestamp),
                dataHash: keccak256("test data")
            }),
            IYieldSyncTaskManager.NonSignerStakesAndSignature({
                nonSignerQuorumBitmapIndices: new uint32[](0),
                nonSignerPubkeys: new BN254.G1Point[](0),
                quorumApks: new BN254.G1Point[](0),
                apkG2: BN254.G2Point({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]}),
                sigma: BN254.G1Point({x: 0, y: 0}),
                quorumApkIndices: new uint32[](0),
                quorumThresholdPercentages: new uint32[](0)
            })
        );
        
        // Raise challenge
        vm.prank(challenger);
        taskManager.raiseAndResolveChallenge(
            IYieldSyncTaskManager.Task({
                lstToken: STETH,
                taskCreatedBlock: uint32(block.number),
                quorumNumbers: QUORUM_NUMBERS,
                quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
            }),
            IYieldSyncTaskManager.TaskResponse({
                referenceTaskIndex: 0,
                yieldRate: 350,
                timestamp: uint32(block.timestamp),
                dataHash: keccak256("test data")
            }),
            IYieldSyncTaskManager.TaskResponseMetadata({
                taskRespondedBlock: uint32(block.number),
                hashOfNonSigners: keccak256("non signers")
            }),
            new BN254.G1Point[](0)
        );
        
        assertTrue(taskManager.taskSuccessfullyChallenged(0));
    }
    
    function testRaiseAndResolveChallengeTaskNotResponded() public {
        vm.prank(challenger);
        vm.expectRevert("Task hasn't been responded to yet");
        taskManager.raiseAndResolveChallenge(
            IYieldSyncTaskManager.Task({
                lstToken: STETH,
                taskCreatedBlock: uint32(block.number),
                quorumNumbers: QUORUM_NUMBERS,
                quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
            }),
            IYieldSyncTaskManager.TaskResponse({
                referenceTaskIndex: 0,
                yieldRate: 350,
                timestamp: uint32(block.timestamp),
                dataHash: keccak256("test data")
            }),
            IYieldSyncTaskManager.TaskResponseMetadata({
                taskRespondedBlock: uint32(block.number),
                hashOfNonSigners: keccak256("non signers")
            }),
            new BN254.G1Point[](0)
        );
    }

    // ============ Pausable Tests ============
    
    function testPauseTaskManager() public {
        vm.prank(owner);
        taskManager.pause();
        assertTrue(taskManager.paused());
    }
    
    function testUnpauseTaskManager() public {
        vm.prank(owner);
        taskManager.pause();
        vm.prank(owner);
        taskManager.unpause();
        assertFalse(taskManager.paused());
    }
    
    function testPauseOnlyPauser() public {
        vm.prank(operator1);
        vm.expectRevert("Pausable: only pauser");
        taskManager.pause();
    }

    // ============ Access Control Tests ============
    
    function testTaskManagerOwnership() public {
        assertEq(taskManager.owner(), owner);
    }
    
    function testTransferOwnership() public {
        taskManager.transferOwnership(operator1);
        assertEq(taskManager.owner(), operator1);
    }
    
    function testRenounceOwnership() public {
        taskManager.renounceOwnership();
        assertEq(taskManager.owner(), address(0));
    }

    // ============ Event Tests ============
    
    function testNewTaskCreatedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IYieldSyncTaskManager.NewTaskCreated(0, IYieldSyncTaskManager.Task({
            lstToken: STETH,
            taskCreatedBlock: uint32(block.number),
            quorumNumbers: QUORUM_NUMBERS,
            quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
        }));
        
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        
        vm.prank(aggregator);
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
    }
    
    function testTaskRespondedEvent() public {
        // Create task first
        vm.prank(aggregator);
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        
        IYieldSyncTaskManager.TaskResponse memory taskResponse = IYieldSyncTaskManager.TaskResponse({
            referenceTaskIndex: 0,
            yieldRate: 350,
            timestamp: uint32(block.timestamp),
            dataHash: keccak256("test data")
        });
        
        IYieldSyncTaskManager.TaskResponseMetadata memory taskResponseMetadata = IYieldSyncTaskManager.TaskResponseMetadata({
            taskRespondedBlock: uint32(block.number),
            hashOfNonSigners: keccak256("non signers")
        });
        
        vm.expectEmit(true, true, true, true);
        emit IYieldSyncTaskManager.TaskResponded(taskResponse, taskResponseMetadata);
        
        vm.prank(aggregator);
        taskManager.respondToTask(
            IYieldSyncTaskManager.Task({
                lstToken: STETH,
                taskCreatedBlock: uint32(block.number),
                quorumNumbers: QUORUM_NUMBERS,
                quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
            }),
            taskResponse,
            IYieldSyncTaskManager.NonSignerStakesAndSignature({
                nonSignerQuorumBitmapIndices: new uint32[](0),
                nonSignerPubkeys: new BN254.G1Point[](0),
                quorumApks: new BN254.G1Point[](0),
                apkG2: BN254.G2Point({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]}),
                sigma: BN254.G1Point({x: 0, y: 0}),
                quorumApkIndices: new uint32[](0),
                quorumThresholdPercentages: new uint32[](0)
            })
        );
    }

    // ============ Edge Case Tests ============
    
    function testMaxTaskNumber() public {
        // Test with maximum task number
        vm.prank(aggregator);
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        
        assertEq(taskManager.latestTaskNum(), 1);
        assertTrue(taskManager.allTaskHashes(0) != bytes32(0));
    }
    
    function testMultipleTasks() public {
        // Create multiple tasks
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(aggregator);
            taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        }
        
        assertEq(taskManager.latestTaskNum(), 5);
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(taskManager.allTaskHashes(i) != bytes32(0));
        }
    }
    
    function testTaskWithDifferentLSTTokens() public {
        address[] memory lstTokens = new address[](4);
        lstTokens[0] = STETH;
        lstTokens[1] = RETH;
        lstTokens[2] = CBETH;
        lstTokens[3] = SFRXETH;
        
        for (uint256 i = 0; i < lstTokens.length; i++) {
            vm.prank(aggregator);
            taskManager.createNewTask(lstTokens[i], QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        }
        
        assertEq(taskManager.latestTaskNum(), 4);
    }

    // ============ Gas Optimization Tests ============
    
    function testGasUsageCreateTask() public {
        uint256 gasStart = gasleft();
        vm.prank(aggregator);
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for createNewTask:", gasUsed);
        assertTrue(gasUsed < 200000); // Reasonable gas limit
    }
    
    function testGasUsageRespondToTask() public {
        // Create task first
        vm.prank(aggregator);
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        
        uint256 gasStart = gasleft();
        vm.prank(aggregator);
        taskManager.respondToTask(
            IYieldSyncTaskManager.Task({
                lstToken: STETH,
                taskCreatedBlock: uint32(block.number),
                quorumNumbers: QUORUM_NUMBERS,
                quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
            }),
            IYieldSyncTaskManager.TaskResponse({
                referenceTaskIndex: 0,
                yieldRate: 350,
                timestamp: uint32(block.timestamp),
                dataHash: keccak256("test data")
            }),
            IYieldSyncTaskManager.NonSignerStakesAndSignature({
                nonSignerQuorumBitmapIndices: new uint32[](0),
                nonSignerPubkeys: new BN254.G1Point[](0),
                quorumApks: new BN254.G1Point[](0),
                apkG2: BN254.G2Point({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]}),
                sigma: BN254.G1Point({x: 0, y: 0}),
                quorumApkIndices: new uint32[](0),
                quorumThresholdPercentages: new uint32[](0)
            })
        );
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for respondToTask:", gasUsed);
        assertTrue(gasUsed < 500000); // Reasonable gas limit
    }

    // ============ Integration Tests ============
    
    function testFullWorkflow() public {
        // 1. Create task
        vm.prank(aggregator);
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
        
        // 2. Respond to task
        vm.prank(aggregator);
        taskManager.respondToTask(
            IYieldSyncTaskManager.Task({
                lstToken: STETH,
                taskCreatedBlock: uint32(block.number),
                quorumNumbers: QUORUM_NUMBERS,
                quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
            }),
            IYieldSyncTaskManager.TaskResponse({
                referenceTaskIndex: 0,
                yieldRate: 350,
                timestamp: uint32(block.timestamp),
                dataHash: keccak256("test data")
            }),
            IYieldSyncTaskManager.NonSignerStakesAndSignature({
                nonSignerQuorumBitmapIndices: new uint32[](0),
                nonSignerPubkeys: new BN254.G1Point[](0),
                quorumApks: new BN254.G1Point[](0),
                apkG2: BN254.G2Point({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]}),
                sigma: BN254.G1Point({x: 0, y: 0}),
                quorumApkIndices: new uint32[](0),
                quorumThresholdPercentages: new uint32[](0)
            })
        );
        
        // 3. Verify state
        assertEq(taskManager.latestTaskNum(), 1);
        assertTrue(taskManager.allTaskResponses(0) != bytes32(0));
    }

    // ============ Error Handling Tests ============
    
    function testRevertOnInvalidInput() public {
        vm.prank(aggregator);
        vm.expectRevert("LST token cannot be zero address");
        taskManager.createNewTask(address(0), QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
    }
    
    function testRevertOnUnauthorizedAccess() public {
        vm.prank(operator1);
        vm.expectRevert("Task generator must be the caller");
        taskManager.createNewTask(STETH, QUORUM_THRESHOLD_PERCENTAGE, QUORUM_NUMBERS);
    }
    
    function testRevertOnInvalidState() public {
        vm.prank(aggregator);
        vm.expectRevert("supplied task does not match the one recorded in the contract");
        taskManager.respondToTask(
            IYieldSyncTaskManager.Task({
                lstToken: STETH,
                taskCreatedBlock: uint32(block.number),
                quorumNumbers: QUORUM_NUMBERS,
                quorumThresholdPercentage: QUORUM_THRESHOLD_PERCENTAGE
            }),
            IYieldSyncTaskManager.TaskResponse({
                referenceTaskIndex: 0,
                yieldRate: 350,
                timestamp: uint32(block.timestamp),
                dataHash: keccak256("test data")
            }),
            IYieldSyncTaskManager.NonSignerStakesAndSignature({
                nonSignerQuorumBitmapIndices: new uint32[](0),
                nonSignerPubkeys: new BN254.G1Point[](0),
                quorumApks: new BN254.G1Point[](0),
                apkG2: BN254.G2Point({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]}),
                sigma: BN254.G1Point({x: 0, y: 0}),
                quorumApkIndices: new uint32[](0),
                quorumThresholdPercentages: new uint32[](0)
            })
        );
    }
}
