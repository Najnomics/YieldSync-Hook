// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/hooks/YieldSyncHook.sol";
import "../src/avs/YieldSyncServiceManager.sol";
import "../src/avs/YieldSyncTaskManager.sol";
import "../src/avs/LSTMonitors/LidoYieldMonitor.sol";
import "../src/avs/LSTMonitors/RocketPoolMonitor.sol";
import "../src/avs/LSTMonitors/CoinbaseMonitor.sol";
import "../src/avs/LSTMonitors/FraxMonitor.sol";

import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {IPauserRegistry} from "@eigenlayer/contracts/interfaces/IPauserRegistry.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";

/**
 * @title Deploy
 * @dev Master deployment script for YieldSync Hook system
 */
contract Deploy is Script {
    
    // Network Configuration
    struct NetworkConfig {
        address poolManager;
        address avsDirectory;
        address slashingRegistryCoordinator;
        address stakeRegistry;
        address rewardsCoordinator;
        address allocationManager;
        address permissionController;
        address pauserRegistry;
        address deployer;
        string networkName;
    }
    
    // Deployment Results
    struct DeploymentResult {
        address yieldSyncHook;
        address yieldSyncServiceManager;
        address yieldSyncTaskManager;
        address lidoYieldMonitor;
        address rocketPoolMonitor;
        address coinbaseMonitor;
        address fraxMonitor;
        string networkName;
        uint256 deploymentBlock;
    }
    
    NetworkConfig public config;
    DeploymentResult public result;
    
    function run() external virtual {
        uint256 chainId = block.chainid;
        console.log("Deploying on chain ID:", chainId);
        
        // Load configuration for the current network
        loadNetworkConfig(chainId);
        
        // Start deployment
        vm.startBroadcast(config.deployer);
        
        // Deploy all contracts
        deployContracts();
        
        // Setup and configure contracts
        configureContracts();
        
        vm.stopBroadcast();
        
        // Log deployment results
        logDeploymentResults();
        
        // Save deployment addresses
        saveDeploymentAddresses();
    }
    
    function loadNetworkConfig(uint256 chainId) internal {
        if (chainId == 1) {
            // Ethereum Mainnet
            loadMainnetConfig();
        } else if (chainId == 5) {
            // Goerli Testnet
            loadGoerliConfig();
        } else if (chainId == 11155111) {
            // Sepolia Testnet  
            loadSepoliaConfig();
        } else if (chainId == 17000) {
            // Holesky Testnet
            loadHoleskyConfig();
        } else if (chainId == 31337) {
            // Local Anvil
            loadAnvilConfig();
        } else {
            revert("Unsupported network");
        }
        
        // Load deployer from environment
        config.deployer = vm.envAddress("DEPLOYER_PRIVATE_KEY_ADDRESS");
        require(config.deployer != address(0), "DEPLOYER_PRIVATE_KEY_ADDRESS not set");
        
        console.log("Network:", config.networkName);
        console.log("Deployer:", config.deployer);
    }
    
    function loadMainnetConfig() internal {
        config = NetworkConfig({
            // Uniswap V4 (when deployed)
            poolManager: 0x0000000000000000000000000000000000000000, // TBD
            // EigenLayer Mainnet
            avsDirectory: 0x135DDa560e946695d6f155dACaFC6f1F25C1F5AF,
            slashingRegistryCoordinator: 0x0000000000000000000000000000000000000000, // TBD
            stakeRegistry: 0x006124AE7976137266feeBfb3f4043C3101820ba,
            rewardsCoordinator: 0x7750d328b314EfFa365A0402CcfD489B80B0adda,
            allocationManager: 0x0000000000000000000000000000000000000000, // TBD  
            permissionController: 0x0000000000000000000000000000000000000000, // TBD
            pauserRegistry: 0x0c431C66F4dE941d089625E5B423D00707977060,
            deployer: address(0),
            networkName: "Mainnet"
        });
    }
    function loadGoerliConfig() internal {
        config = NetworkConfig({
            poolManager: 0x0000000000000000000000000000000000000000, // Mock for testnet
            avsDirectory: 0x0000000000000000000000000000000000000000, // Mock for testnet
            slashingRegistryCoordinator: 0x0000000000000000000000000000000000000000,
            stakeRegistry: 0x0000000000000000000000000000000000000000,
            rewardsCoordinator: 0x0000000000000000000000000000000000000000,
            allocationManager: 0x0000000000000000000000000000000000000000,
            permissionController: 0x0000000000000000000000000000000000000000,
            pauserRegistry: 0x0000000000000000000000000000000000000000,
            deployer: address(0),
            networkName: "Goerli"
        });
    }
    
    function loadSepoliaConfig() internal {
        config = NetworkConfig({
            poolManager: 0x0000000000000000000000000000000000000000, // Mock for testnet
            avsDirectory: 0x0000000000000000000000000000000000000000, // Mock for testnet  
            slashingRegistryCoordinator: 0x0000000000000000000000000000000000000000,
            stakeRegistry: 0x0000000000000000000000000000000000000000,
            rewardsCoordinator: 0x0000000000000000000000000000000000000000,
            allocationManager: 0x0000000000000000000000000000000000000000,
            permissionController: 0x0000000000000000000000000000000000000000,
            pauserRegistry: 0x0000000000000000000000000000000000000000,
            deployer: address(0),
            networkName: "Sepolia"
        });
    }
    
    function loadHoleskyConfig() internal {
        config = NetworkConfig({
            // Holesky EigenLayer Testnet addresses
            poolManager: 0x0000000000000000000000000000000000000000, // Mock for testnet
            avsDirectory: 0x055733000064333CaDDbC92763c58BF0192fFeBf,
            slashingRegistryCoordinator: 0x0000000000000000000000000000000000000000,
            stakeRegistry: 0x012c0D3524E6B3F020690825f2e2b40C639C82Cf,
            rewardsCoordinator: 0xAcc1fb458a1317E886dB376Fc8141540537E68fE,
            allocationManager: 0x0000000000000000000000000000000000000000,
            permissionController: 0x0000000000000000000000000000000000000000,
            pauserRegistry: 0x85Ef7299F8311B25642679edBF02B62FA2212F06,
            deployer: address(0),
            networkName: "Holesky"
        });
    }
    
    function loadAnvilConfig() internal {
        config = NetworkConfig({
            poolManager: 0x0000000000000000000000000000000000000000, // Will deploy mock
            avsDirectory: 0x0000000000000000000000000000000000000000, // Will deploy mock
            slashingRegistryCoordinator: 0x0000000000000000000000000000000000000000,
            stakeRegistry: 0x0000000000000000000000000000000000000000,
            rewardsCoordinator: 0x0000000000000000000000000000000000000000,
            allocationManager: 0x0000000000000000000000000000000000000000,
            permissionController: 0x0000000000000000000000000000000000000000,
            pauserRegistry: 0x0000000000000000000000000000000000000000,
            deployer: address(0),
            networkName: "Anvil"
        });
    }
    
    function deployContracts() internal {
        console.log("=== Starting Contract Deployment ===");
        
        // For local/testnet, deploy mocks first
        if (block.chainid == 31337 || config.avsDirectory == address(0)) {
            deployMockContracts();
        }
        
        // 1. Deploy LST Monitors
        console.log("Deploying LST Monitors...");
        result.lidoYieldMonitor = address(new LidoYieldMonitor());
        result.rocketPoolMonitor = address(new RocketPoolMonitor());
        result.coinbaseMonitor = address(new CoinbaseMonitor());
        result.fraxMonitor = address(new FraxMonitor());
        
        console.log("LidoYieldMonitor deployed at:", result.lidoYieldMonitor);
        console.log("RocketPoolMonitor deployed at:", result.rocketPoolMonitor);
        console.log("CoinbaseMonitor deployed at:", result.coinbaseMonitor);
        console.log("FraxMonitor deployed at:", result.fraxMonitor);
        
        // 2. Deploy Task Manager
        console.log("Deploying YieldSyncTaskManager...");
        result.yieldSyncTaskManager = address(new YieldSyncTaskManager(
            ISlashingRegistryCoordinator(config.slashingRegistryCoordinator),
            IPauserRegistry(config.pauserRegistry),
            100 // TASK_RESPONSE_WINDOW_BLOCK
        ));
        console.log("YieldSyncTaskManager deployed at:", result.yieldSyncTaskManager);
        
        // 3. Deploy Service Manager
        console.log("Deploying YieldSyncServiceManager...");
        result.yieldSyncServiceManager = address(new YieldSyncServiceManager(
            IAVSDirectory(config.avsDirectory),
            ISlashingRegistryCoordinator(config.slashingRegistryCoordinator),
            IStakeRegistry(config.stakeRegistry),
            config.rewardsCoordinator,
            IAllocationManager(config.allocationManager),
            IPermissionController(config.permissionController),
            IYieldSyncTaskManager(result.yieldSyncTaskManager)
        ));
        console.log("YieldSyncServiceManager deployed at:", result.yieldSyncServiceManager);
        
        // 4. Deploy YieldSync Hook
        console.log("Deploying YieldSyncHook...");
        result.yieldSyncHook = address(new YieldSyncHook(
            IPoolManager(config.poolManager),
            IYieldSyncAVS(result.yieldSyncServiceManager)
        ));
        console.log("YieldSyncHook deployed at:", result.yieldSyncHook);
        
        result.networkName = config.networkName;
        result.deploymentBlock = block.number;
        
        console.log("=== Contract Deployment Complete ===");
    }
    
    function deployMockContracts() internal {
        console.log("Deploying mock contracts for local/testnet...");
        
        // Deploy minimal mocks for testing
        if (config.poolManager == address(0)) {
            config.poolManager = address(new MockPoolManager());
            console.log("MockPoolManager deployed at:", config.poolManager);
        }
        
        if (config.avsDirectory == address(0)) {
            config.avsDirectory = address(new MockAVSDirectory());
            console.log("MockAVSDirectory deployed at:", config.avsDirectory);
        }
        
        // Deploy other required mocks
        if (config.slashingRegistryCoordinator == address(0)) {
            config.slashingRegistryCoordinator = address(new MockSlashingRegistryCoordinator());
        }
        
        if (config.stakeRegistry == address(0)) {
            config.stakeRegistry = address(new MockStakeRegistry());
        }
        
        if (config.rewardsCoordinator == address(0)) {
            config.rewardsCoordinator = address(new MockRewardsCoordinator());
        }
        
        if (config.allocationManager == address(0)) {
            config.allocationManager = address(new MockAllocationManager());
        }
        
        if (config.permissionController == address(0)) {
            config.permissionController = address(new MockPermissionController());
        }
        
        if (config.pauserRegistry == address(0)) {
            config.pauserRegistry = address(new MockPauserRegistry());
        }
    }
    
    function configureContracts() internal {
        console.log("=== Configuring Contracts ===");
        
        // Initialize Service Manager
        YieldSyncServiceManager serviceManager = YieldSyncServiceManager(result.yieldSyncServiceManager);
        serviceManager.initialize(config.deployer, config.deployer);
        console.log("ServiceManager initialized");
        
        // No additional configuration needed for other contracts
        // Pool configurations will be done post-deployment
        
        console.log("=== Contract Configuration Complete ===");
    }
    
    function logDeploymentResults() internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:", result.networkName);
        console.log("Deployment Block:", result.deploymentBlock);
        console.log("");
        console.log("Contract Addresses:");
        console.log("YieldSyncHook:", result.yieldSyncHook);
        console.log("YieldSyncServiceManager:", result.yieldSyncServiceManager);
        console.log("YieldSyncTaskManager:", result.yieldSyncTaskManager);
        console.log("LidoYieldMonitor:", result.lidoYieldMonitor);
        console.log("RocketPoolMonitor:", result.rocketPoolMonitor);
        console.log("CoinbaseMonitor:", result.coinbaseMonitor);
        console.log("FraxMonitor:", result.fraxMonitor);
        console.log("========================");
    }
    
    function saveDeploymentAddresses() internal {
        string memory json = "deployments";
        
        vm.serializeAddress(json, "yieldSyncHook", result.yieldSyncHook);
        vm.serializeAddress(json, "yieldSyncServiceManager", result.yieldSyncServiceManager);
        vm.serializeAddress(json, "yieldSyncTaskManager", result.yieldSyncTaskManager);
        vm.serializeAddress(json, "lidoYieldMonitor", result.lidoYieldMonitor);
        vm.serializeAddress(json, "rocketPoolMonitor", result.rocketPoolMonitor);
        vm.serializeAddress(json, "coinbaseMonitor", result.coinbaseMonitor);
        vm.serializeAddress(json, "fraxMonitor", result.fraxMonitor);
        vm.serializeString(json, "networkName", result.networkName);
        string memory finalJson = vm.serializeUint(json, "deploymentBlock", result.deploymentBlock);
        
        string memory filename = string.concat("deployments/", result.networkName, ".json");
        vm.writeJson(finalJson, filename);
        
        console.log("Deployment addresses saved to:", filename);
    }
}

// Minimal Mock Contracts for Testing

contract MockPoolManager {
    function initialize(address, uint160) external pure returns (bytes4) {
        return this.initialize.selector;
    }
}

contract MockAVSDirectory {
    function updateAVSMetadataURI(string calldata) external {}
}

contract MockSlashingRegistryCoordinator {
    // Mock implementation
}

contract MockStakeRegistry {
    // Mock implementation  
}

contract MockRewardsCoordinator {
    // Mock implementation
}

contract MockAllocationManager {
    // Mock implementation
}

contract MockPermissionController {
    // Mock implementation
}

contract MockPauserRegistry {
    // Mock implementation
}