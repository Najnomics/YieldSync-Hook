// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {YieldSyncHook} from "../src/hooks/YieldSyncHook.sol";
import {YieldSyncServiceManager} from "../src/avs/YieldSyncServiceManager.sol";
import {YieldSyncTaskManager} from "../src/avs/YieldSyncTaskManager.sol";
import {IYieldSyncTaskManager} from "../src/avs/IYieldSyncTaskManager.sol";
import {IYieldSyncAVS} from "../src/avs/interfaces/IYieldSyncAVS.sol";
import "../src/avs/LSTMonitors/LidoYieldMonitor.sol";
import "../src/avs/LSTMonitors/RocketPoolMonitor.sol";
import "../src/avs/LSTMonitors/CoinbaseMonitor.sol";
import "../src/avs/LSTMonitors/FraxMonitor.sol";

import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {IPauserRegistry} from "@eigenlayer/contracts/interfaces/IPauserRegistry.sol";

/**
 * @title DeployYieldSync
 * @dev Deployment script for YieldSync Hook and AVS components
 * @notice Follows EigenLayer deployment patterns
 */
contract DeployYieldSync is Script {
    
    // EigenLayer contract addresses
    address public avsDirectory;
    address public slashingRegistryCoordinator;
    address public stakeRegistry;
    address public permissionController;
    address public allocationManager;
    address public rewardsCoordinator;
    address public pauserRegistry;
    
    // Uniswap V4 contract addresses
    address public poolManager;
    
    // Deployed contracts
    YieldSyncHook public yieldSyncHook;
    YieldSyncServiceManager public yieldSyncServiceManager;
    YieldSyncTaskManager public yieldSyncTaskManager;
    LidoYieldMonitor public lidoMonitor;
    RocketPoolMonitor public rocketPoolMonitor;
    CoinbaseMonitor public coinbaseMonitor;
    FraxMonitor public fraxMonitor;
    
    // Deployment parameters
    uint32 public constant TASK_RESPONSE_WINDOW_BLOCK = 100;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying YieldSync with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Load EigenLayer contract addresses
        _loadEigenLayerAddresses();
        
        // Deploy LST monitors first
        _deployLSTMonitors();
        
        // Deploy Task Manager
        _deployTaskManager();
        
        // Deploy AVS Service Manager
        _deployAVSServiceManager();
        
        // Deploy YieldSync Hook
        _deployYieldSyncHook();
        
        // Configure the system
        _configureSystem();
        
        vm.stopBroadcast();
        
        _logDeploymentInfo();
    }
    
    function _loadEigenLayerAddresses() internal {
        console.log("Loading EigenLayer contract addresses...");
        
        avsDirectory = vm.envOr("AVS_DIRECTORY", address(0));
        slashingRegistryCoordinator = vm.envOr("SLASHING_REGISTRY_COORDINATOR", address(0));
        stakeRegistry = vm.envOr("STAKE_REGISTRY", address(0));
        permissionController = vm.envOr("PERMISSION_CONTROLLER", address(0));
        allocationManager = vm.envOr("ALLOCATION_MANAGER", address(0));
        rewardsCoordinator = vm.envOr("REWARDS_COORDINATOR", address(0));
        pauserRegistry = vm.envOr("PAUSER_REGISTRY", address(0));
        poolManager = vm.envOr("POOL_MANAGER", address(0));
        
        require(avsDirectory != address(0), "AVS_DIRECTORY not set");
        require(slashingRegistryCoordinator != address(0), "SLASHING_REGISTRY_COORDINATOR not set");
        require(stakeRegistry != address(0), "STAKE_REGISTRY not set");
        require(permissionController != address(0), "PERMISSION_CONTROLLER not set");
        require(allocationManager != address(0), "ALLOCATION_MANAGER not set");
        require(rewardsCoordinator != address(0), "REWARDS_COORDINATOR not set");
        require(pauserRegistry != address(0), "PAUSER_REGISTRY not set");
        require(poolManager != address(0), "POOL_MANAGER not set");
        
        console.log("EigenLayer addresses loaded successfully");
    }
    
    function _deployLSTMonitors() internal {
        console.log("Deploying LST monitors...");
        
        lidoMonitor = new LidoYieldMonitor();
        console.log("LidoYieldMonitor deployed at:", address(lidoMonitor));
        
        rocketPoolMonitor = new RocketPoolMonitor();
        console.log("RocketPoolMonitor deployed at:", address(rocketPoolMonitor));
        
        coinbaseMonitor = new CoinbaseMonitor();
        console.log("CoinbaseMonitor deployed at:", address(coinbaseMonitor));
        
        fraxMonitor = new FraxMonitor();
        console.log("FraxMonitor deployed at:", address(fraxMonitor));
    }
    
    function _deployTaskManager() internal {
        console.log("Deploying YieldSync Task Manager...");
        
        yieldSyncTaskManager = new YieldSyncTaskManager(
            ISlashingRegistryCoordinator(slashingRegistryCoordinator),
            IPauserRegistry(pauserRegistry),
            TASK_RESPONSE_WINDOW_BLOCK
        );
        
        // Initialize the task manager
        yieldSyncTaskManager.initialize(
            msg.sender,                    // initialOwner
            msg.sender,                    // aggregator (placeholder)
            msg.sender,                    // generator (placeholder)
            allocationManager,             // allocationManager
            address(0),                    // slasher (placeholder)
            address(0)                     // serviceManager (will be set after deployment)
        );
        
        console.log("YieldSyncTaskManager deployed at:", address(yieldSyncTaskManager));
    }
    
    function _deployAVSServiceManager() internal {
        console.log("Deploying YieldSync Service Manager...");
        
        yieldSyncServiceManager = new YieldSyncServiceManager(
            IAVSDirectory(avsDirectory),
            ISlashingRegistryCoordinator(slashingRegistryCoordinator),
            IStakeRegistry(stakeRegistry),
            rewardsCoordinator,
            IAllocationManager(allocationManager),
            IPermissionController(permissionController),
            IYieldSyncTaskManager(address(yieldSyncTaskManager))
        );
        
        // Initialize the service manager
        yieldSyncServiceManager.initialize(msg.sender, msg.sender);
        
        console.log("YieldSyncServiceManager deployed at:", address(yieldSyncServiceManager));
    }
    
    function _deployYieldSyncHook() internal {
        console.log("Deploying YieldSync Hook...");
        
        yieldSyncHook = new YieldSyncHook(
            IPoolManager(poolManager),
            IYieldSyncAVS(address(yieldSyncServiceManager))
        );
        
        console.log("YieldSyncHook deployed at:", address(yieldSyncHook));
    }
    
    function _configureSystem() internal {
        console.log("Configuring system...");
        
        // Update LST monitors in service manager (if needed)
        // This would be done through the service manager's updateLSTMonitor function
        // yieldSyncServiceManager.updateLSTMonitor(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84, address(lidoMonitor));
        
        console.log("System configuration completed");
    }
    
    function _logDeploymentInfo() internal view {
        console.log("\n=== YieldSync Deployment Complete ===");
        console.log("YieldSyncHook:", address(yieldSyncHook));
        console.log("YieldSyncServiceManager:", address(yieldSyncServiceManager));
        console.log("YieldSyncTaskManager:", address(yieldSyncTaskManager));
        console.log("LidoYieldMonitor:", address(lidoMonitor));
        console.log("RocketPoolMonitor:", address(rocketPoolMonitor));
        console.log("CoinbaseMonitor:", address(coinbaseMonitor));
        console.log("FraxMonitor:", address(fraxMonitor));
        console.log("=====================================\n");
        
        console.log("Next steps:");
        console.log("1. Register the AVS with EigenLayer");
        console.log("2. Register operators with the AVS");
        console.log("3. Deploy the hook to Uniswap V4 pools");
        console.log("4. Start the Go operator services");
    }
}