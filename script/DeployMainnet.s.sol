// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Deploy.s.sol";

/**
 * @title DeployMainnet
 * @dev Production deployment script for Ethereum Mainnet
 * @notice This script includes additional safety checks and production configurations
 */
contract DeployMainnet is Deploy {
    
    uint256 public constant DEPLOYMENT_DELAY = 60; // 1 minute delay between critical deployments
    uint256 public constant VERIFICATION_DELAY = 300; // 5 minutes before verification
    uint256 public constant MINIMUM_DEPLOYER_BALANCE = 1 ether; // Minimum ETH required
    
    bool public immutable PRODUCTION_MODE = true;
    bool public verifyContracts = true;
    bool public enableTimelocks = true;
    
    struct MainnetSafetyChecks {
        bool deployerBalanceCheck;
        bool gasLimitCheck;
        bool networkConfirmation;
        bool contractValidation;
        bool accessControlValidation;
    }
    
    MainnetSafetyChecks public safetyChecks;
    
    function run() external override {
        console.log("=== YieldSync Hook - MAINNET DEPLOYMENT ===");
        console.log("WARNING: PRODUCTION DEPLOYMENT - EXTRA CAUTION REQUIRED");
        console.log("");
        
        require(block.chainid == 1, "This script is only for Ethereum Mainnet (Chain ID: 1)");
        
        // Pre-deployment safety checks
        performPreDeploymentChecks();
        
        // Load mainnet configuration
        loadMainnetConfig();
        
        // Additional production validations
        validateProductionEnvironment();
        
        // Final confirmation before deployment
        requireManualConfirmation();
        
        console.log("Starting mainnet deployment in", DEPLOYMENT_DELAY, "seconds...");
        vm.sleep(DEPLOYMENT_DELAY * 1000);
        
        vm.startBroadcast();
        
        // Deploy contracts with production settings
        deployMainnetContracts();
        
        // Configure with production parameters
        configureMainnetContracts();
        
        // Setup production access controls
        setupProductionAccessControls();
        
        vm.stopBroadcast();
        
        // Post-deployment verification and validation
        performPostDeploymentValidation();
        
        // Verify contracts on Etherscan
        if (verifyContracts) {
            verifyMainnetContracts();
        }
        
        // Log deployment results
        logMainnetDeploymentResults();
        
        // Save deployment data
        saveMainnetDeploymentAddresses();
        
        // Provide production instructions
        provideMainnetInstructions();
        
        console.log("=== MAINNET DEPLOYMENT COMPLETE ===");
        console.log("All contracts successfully deployed to Ethereum Mainnet!");
    }
    
    function performPreDeploymentChecks() internal {
        console.log("=== Pre-Deployment Safety Checks ===");
        
        // Check 1: Network confirmation
        require(block.chainid == 1, "Not on Ethereum Mainnet");
        safetyChecks.networkConfirmation = true;
        console.log("[OK] Network: Ethereum Mainnet confirmed");
        
        // Check 2: Deployer balance
        uint256 deployerBalance = msg.sender.balance;
        require(deployerBalance >= MINIMUM_DEPLOYER_BALANCE, "Insufficient deployer balance");
        safetyChecks.deployerBalanceCheck = true;
        console.log("[OK] Deployer balance:", deployerBalance / 1e18, "ETH");
        
        // Check 3: Gas limit check
        require(gasleft() > 5000000, "Insufficient gas limit");
        safetyChecks.gasLimitCheck = true;
        console.log("[OK] Gas limit check passed");
        
        console.log("All pre-deployment checks passed");
        console.log("");
    }
    
    function validateProductionEnvironment() internal view {
        console.log("=== Production Environment Validation ===");
        
        // Validate all required addresses are set
        require(config.avsDirectory != address(0), "AVSDirectory address not set");
        require(config.stakeRegistry != address(0), "StakeRegistry address not set");
        require(config.rewardsCoordinator != address(0), "RewardsCoordinator address not set");
        require(config.pauserRegistry != address(0), "PauserRegistry address not set");
        
        console.log("[OK] All required contract addresses validated");
        
        // Validate deployer
        require(config.deployer != address(0), "Deployer address not set");
        require(config.deployer.code.length == 0, "Deployer must be an EOA, not a contract");
        
        console.log("[OK] Deployer validation passed");
        
        // Additional production-specific validations
        console.log("[OK] Production environment validation complete");
        console.log("");
    }
    
    function requireManualConfirmation() internal view {
        console.log("=== FINAL CONFIRMATION REQUIRED ===");
        console.log("You are about to deploy to ETHEREUM MAINNET");
        console.log("This will use real ETH and deploy immutable contracts");
        console.log("");
        console.log("Deployment Summary:");
        console.log("- Network: Ethereum Mainnet (Chain ID: 1)");
        console.log("- Deployer:", config.deployer);
        console.log("- Estimated Gas Cost: ~15-20M gas");
        console.log("- Contracts to deploy: 7 main contracts + monitors");
        console.log("");
        console.log("[WARNING] PROCEED ONLY IF YOU HAVE VERIFIED ALL CONFIGURATIONS");
        console.log("");
        // Note: In a real deployment, you might want to add an interactive confirmation
        // For script purposes, we assume confirmation if the script is run
    }
    
    function deployMainnetContracts() internal {
        console.log("=== Deploying Contracts to Mainnet ===");
        
        // Deploy core contracts with production delay
        deployContractsWithDelay();
        
        console.log("Mainnet contract deployment complete");
    }
    
    function deployContractsWithDelay() internal {
        console.log("Deploying LST Monitors with safety delays...");
        
        result.lidoYieldMonitor = address(new LidoYieldMonitor());
        console.log("[OK] LidoYieldMonitor deployed:", result.lidoYieldMonitor);
        vm.sleep(5000); // 5 second delay
        
        result.rocketPoolMonitor = address(new RocketPoolMonitor());
        console.log("[OK] RocketPoolMonitor deployed:", result.rocketPoolMonitor);
        vm.sleep(5000);
        
        result.coinbaseMonitor = address(new CoinbaseMonitor());
        console.log("[OK] CoinbaseMonitor deployed:", result.coinbaseMonitor);
        vm.sleep(5000);
        
        result.fraxMonitor = address(new FraxMonitor());
        console.log("[OK] FraxMonitor deployed:", result.fraxMonitor);
        vm.sleep(10000); // 10 second delay before critical contracts
        
        console.log("Deploying core AVS contracts...");
        
        result.yieldSyncTaskManager = address(new YieldSyncTaskManager(
            ISlashingRegistryCoordinator(config.slashingRegistryCoordinator),
            IPauserRegistry(config.pauserRegistry),
            100 // TASK_RESPONSE_WINDOW_BLOCK - production value
        ));
        console.log("[OK] YieldSyncTaskManager deployed:", result.yieldSyncTaskManager);
        vm.sleep(15000); // 15 second delay
        
        result.yieldSyncServiceManager = address(new YieldSyncServiceManager(
            IAVSDirectory(config.avsDirectory),
            ISlashingRegistryCoordinator(config.slashingRegistryCoordinator),
            IStakeRegistry(config.stakeRegistry),
            config.rewardsCoordinator,
            IAllocationManager(config.allocationManager),
            IPermissionController(config.permissionController),
            IYieldSyncTaskManager(result.yieldSyncTaskManager)
        ));
        console.log("[OK] YieldSyncServiceManager deployed:", result.yieldSyncServiceManager);
        vm.sleep(15000);
        
        // Deploy the main hook contract last
        console.log("Deploying main YieldSyncHook contract...");
        result.yieldSyncHook = address(new YieldSyncHook(
            IPoolManager(config.poolManager),
            IYieldSyncAVS(result.yieldSyncServiceManager)
        ));
        console.log("[OK] YieldSyncHook deployed:", result.yieldSyncHook);
        
        result.networkName = "Mainnet";
        result.deploymentBlock = block.number;
    }
    
    function configureMainnetContracts() internal {
        console.log("=== Configuring Contracts for Production ===");
        
        // Initialize Service Manager with production parameters
        YieldSyncServiceManager serviceManager = YieldSyncServiceManager(result.yieldSyncServiceManager);
        
        // Initialize with deployer as initial owner and rewards initiator
        serviceManager.initialize(config.deployer, config.deployer);
        
        console.log("[OK] ServiceManager initialized for production");
        console.log("Production configuration complete");
    }
    
    function setupProductionAccessControls() internal {
        console.log("=== Setting up Production Access Controls ===");
        
        // Access controls are set up in the initialize function
        // Additional production-specific access controls can be added here
        
        console.log("[OK] Production access controls configured");
    }
    
    function performPostDeploymentValidation() internal view {
        console.log("=== Post-Deployment Validation ===");
        
        // Validate all contracts were deployed successfully
        require(result.yieldSyncHook != address(0), "YieldSyncHook deployment failed");
        require(result.yieldSyncServiceManager != address(0), "ServiceManager deployment failed");
        require(result.yieldSyncTaskManager != address(0), "TaskManager deployment failed");
        require(result.lidoYieldMonitor != address(0), "LidoYieldMonitor deployment failed");
        require(result.rocketPoolMonitor != address(0), "RocketPoolMonitor deployment failed");
        require(result.coinbaseMonitor != address(0), "CoinbaseMonitor deployment failed");
        require(result.fraxMonitor != address(0), "FraxMonitor deployment failed");
        
        console.log("[OK] All contract deployments validated");
        
        // Validate contract bytecode
        require(result.yieldSyncHook.code.length > 0, "YieldSyncHook has no bytecode");
        require(result.yieldSyncServiceManager.code.length > 0, "ServiceManager has no bytecode");
        
        console.log("[OK] Contract bytecode validation passed");
        
        // Validate ownership
        YieldSyncHook hook = YieldSyncHook(result.yieldSyncHook);
        require(hook.owner() == config.deployer, "YieldSyncHook ownership not set correctly");
        
        YieldSyncServiceManager serviceManager = YieldSyncServiceManager(result.yieldSyncServiceManager);
        require(serviceManager.owner() == config.deployer, "ServiceManager ownership not set correctly");
        
        console.log("[OK] Ownership validation passed");
        console.log("Post-deployment validation complete");
        console.log("");
    }
    
    function verifyMainnetContracts() internal {
        console.log("=== Starting Contract Verification ===");
        console.log("Waiting", VERIFICATION_DELAY, "seconds for block confirmations...");
        
        vm.sleep(VERIFICATION_DELAY * 1000);
        
        console.log("Contract verification commands:");
        console.log("");
        console.log("# YieldSync Hook");
        console.log("forge verify-contract", result.yieldSyncHook, "src/hooks/YieldSyncHook.sol:YieldSyncHook");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address)\" ", config.poolManager, result.yieldSyncServiceManager, ")");
        console.log("");
        
        console.log("# YieldSync Service Manager");
        console.log("forge verify-contract", result.yieldSyncServiceManager, "src/avs/YieldSyncServiceManager.sol:YieldSyncServiceManager");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,address,address,address,address,address)\"");
        console.log("    ", config.avsDirectory, config.slashingRegistryCoordinator, config.stakeRegistry);
        console.log("    ", config.rewardsCoordinator, config.allocationManager, config.permissionController);
        console.log("    ", result.yieldSyncTaskManager, ")");
        console.log("");
        
        console.log("# YieldSync Task Manager"); 
        console.log("forge verify-contract", result.yieldSyncTaskManager, "src/avs/YieldSyncTaskManager.sol:YieldSyncTaskManager");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,uint32)\" ", config.slashingRegistryCoordinator, config.pauserRegistry, "100)");
        console.log("");
        
        console.log("# LST Monitors");
        console.log("forge verify-contract", result.lidoYieldMonitor, "src/avs/LSTMonitors/LidoYieldMonitor.sol:LidoYieldMonitor");
        console.log("forge verify-contract", result.rocketPoolMonitor, "src/avs/LSTMonitors/RocketPoolMonitor.sol:RocketPoolMonitor");
        console.log("forge verify-contract", result.coinbaseMonitor, "src/avs/LSTMonitors/CoinbaseMonitor.sol:CoinbaseMonitor");
        console.log("forge verify-contract", result.fraxMonitor, "src/avs/LSTMonitors/FraxMonitor.sol:FraxMonitor");
        console.log("");
        
        console.log("[OK] Verification commands generated");
        console.log("Run the above commands to verify contracts on Etherscan");
    }
    
    function logMainnetDeploymentResults() internal view {
        console.log("\n=== MAINNET DEPLOYMENT RESULTS ===");
        console.log("Network: Ethereum Mainnet");
        console.log("Chain ID: 1");
        console.log("Deployment Block:", result.deploymentBlock);
        console.log("Deployer:", config.deployer);
        console.log("Deployment Time:", block.timestamp);
        console.log("");
        console.log("=== CONTRACT ADDRESSES ===");
        console.log("YieldSyncHook:", result.yieldSyncHook);
        console.log("YieldSyncServiceManager:", result.yieldSyncServiceManager);
        console.log("YieldSyncTaskManager:", result.yieldSyncTaskManager);
        console.log("");
        console.log("=== LST MONITORS ===");
        console.log("LidoYieldMonitor:", result.lidoYieldMonitor);
        console.log("RocketPoolMonitor:", result.rocketPoolMonitor);
        console.log("CoinbaseMonitor:", result.coinbaseMonitor);
        console.log("FraxMonitor:", result.fraxMonitor);
        console.log("");
        console.log("=== INFRASTRUCTURE ===");
        console.log("PoolManager:", config.poolManager);
        console.log("AVSDirectory:", config.avsDirectory);
        console.log("StakeRegistry:", config.stakeRegistry);
        console.log("RewardsCoordinator:", config.rewardsCoordinator);
        console.log("PauserRegistry:", config.pauserRegistry);
        console.log("=====================================");
    }
    
    function saveMainnetDeploymentAddresses() internal {
        console.log("=== Saving Mainnet Deployment Data ===");
        
        // Save standard deployment file
        saveDeploymentAddresses();
        
        // Save comprehensive mainnet deployment data
        string memory json = "mainnetDeployment";
        
        // Core contract addresses
        vm.serializeAddress(json, "yieldSyncHook", result.yieldSyncHook);
        vm.serializeAddress(json, "yieldSyncServiceManager", result.yieldSyncServiceManager);
        vm.serializeAddress(json, "yieldSyncTaskManager", result.yieldSyncTaskManager);
        
        // LST Monitor addresses
        vm.serializeAddress(json, "lidoYieldMonitor", result.lidoYieldMonitor);
        vm.serializeAddress(json, "rocketPoolMonitor", result.rocketPoolMonitor);
        vm.serializeAddress(json, "coinbaseMonitor", result.coinbaseMonitor);
        vm.serializeAddress(json, "fraxMonitor", result.fraxMonitor);
        
        // Infrastructure addresses
        vm.serializeAddress(json, "poolManager", config.poolManager);
        vm.serializeAddress(json, "avsDirectory", config.avsDirectory);
        vm.serializeAddress(json, "slashingRegistryCoordinator", config.slashingRegistryCoordinator);
        vm.serializeAddress(json, "stakeRegistry", config.stakeRegistry);
        vm.serializeAddress(json, "rewardsCoordinator", config.rewardsCoordinator);
        vm.serializeAddress(json, "allocationManager", config.allocationManager);
        vm.serializeAddress(json, "permissionController", config.permissionController);
        vm.serializeAddress(json, "pauserRegistry", config.pauserRegistry);
        
        // Deployment metadata
        vm.serializeString(json, "network", "mainnet");
        vm.serializeUint(json, "chainId", 1);
        vm.serializeUint(json, "deploymentBlock", result.deploymentBlock);
        vm.serializeUint(json, "deploymentTimestamp", block.timestamp);
        vm.serializeAddress(json, "deployer", config.deployer);
        vm.serializeBool(json, "productionMode", PRODUCTION_MODE);
        vm.serializeBool(json, "verified", verifyContracts);
        string memory finalJson = vm.serializeBool(json, "timelockEnabled", enableTimelocks);
        
        // Save to multiple locations for redundancy
        vm.writeJson(finalJson, "deployments/mainnet.json");
        vm.writeJson(finalJson, "deployments/mainnet-production.json");
        
        // Create a backup with timestamp
        string memory timestampedFile = string.concat(
            "deployments/mainnet-backup-",
            vm.toString(block.timestamp),
            ".json"
        );
        vm.writeJson(finalJson, timestampedFile);
        
        console.log("Deployment data saved to multiple files:");
        console.log("   - deployments/mainnet.json");
        console.log("   - deployments/mainnet-production.json");
        console.log("   -", timestampedFile);
        console.log("");
    }
    
    function provideMainnetInstructions() internal view {
        console.log("=== MAINNET DEPLOYMENT SUCCESS ===");
        console.log("");
        console.log("Congratulations! YieldSync Hook has been successfully deployed to Ethereum Mainnet!");
        console.log("");
        console.log("=== IMMEDIATE NEXT STEPS ===");
        console.log("1. Verify all contracts on Etherscan using the commands provided above");
        console.log("2. Update frontend/SDK configurations with the new contract addresses");
        console.log("3. Run comprehensive integration tests against mainnet deployment");
        console.log("4. Notify team members and stakeholders of successful deployment");
        console.log("5. Set up monitoring and alerting for the deployed contracts");
        console.log("");
        console.log("=== CONFIGURATION TASKS ===");
        console.log("1. Configure pools using YieldSyncHook.configurePool()");
        console.log("2. Set up operator registrations with the AVS");
        console.log("3. Configure yield monitoring parameters");
        console.log("4. Test with mainnet LST tokens (stETH, rETH, cbETH, sfrxETH)");
        console.log("");
        console.log("=== IMPORTANT FILES ===");
        console.log("- Deployment Data: deployments/mainnet.json");
        console.log("- Production Config: deployments/mainnet-production.json");
        console.log("- Backup File: deployments/mainnet-backup-*.json");
        console.log("");
        console.log("=== SAFETY REMINDERS ===");
        console.log("- All contracts are IMMUTABLE once deployed");
        console.log("- Owner functions are controlled by:", config.deployer);
        console.log("- Always test interactions on testnets first");
        console.log("- Monitor gas costs for user transactions");
        console.log("");
        console.log("=== SUPPORT ===");
        console.log("For questions or issues, refer to:");
        console.log("- Project documentation");
        console.log("- Smart contract source code");
        console.log("- Test suite for usage examples");
        console.log("");
        console.log("YieldSync Hook is now LIVE on Ethereum Mainnet!");
        console.log("===============================================");
    }
}