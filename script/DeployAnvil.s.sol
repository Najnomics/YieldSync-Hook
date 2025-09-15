// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Deploy.s.sol";

/**
 * @title DeployAnvil
 * @dev Specialized deployment script for local Anvil development
 */
contract DeployAnvil is Deploy {
    
    function run() external override {
        console.log("=== YieldSync Hook - Anvil Deployment ===");
        console.log("Chain ID:", block.chainid);
        
        // Set up local development environment
        setupLocalEnvironment();
        
        // Load Anvil-specific configuration
        loadAnvilConfig();
        
        // Use default anvil account if no private key provided
        if (config.deployer == address(0)) {
            config.deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Default anvil account
            console.log("Using default anvil deployer:", config.deployer);
        }
        
        vm.startBroadcast();
        
        // Deploy all contracts with local optimizations
        deployLocalContracts();
        
        // Configure for local testing
        configureLocalContracts();
        
        // Setup test data
        setupTestData();
        
        vm.stopBroadcast();
        
        // Log results
        logLocalDeploymentResults();
        
        // Save to local file
        saveLocalDeploymentAddresses();
        
        console.log("=== Anvil Deployment Complete ===");
        console.log("Ready for local testing and development");
    }
    
    function setupLocalEnvironment() internal {
        console.log("Setting up local development environment...");
        
        // Create deployments directory if it doesn't exist
        try vm.createDir("deployments", true) {
            console.log("Created deployments directory");
        } catch {
            console.log("Deployments directory already exists");
        }
        
        try vm.createDir("logs", true) {
            console.log("Created logs directory");
        } catch {
            console.log("Logs directory already exists");
        }
    }
    
    function deployLocalContracts() internal {
        console.log("=== Deploying Contracts for Local Development ===");
        
        // Deploy comprehensive mocks for full local testing
        deployAdvancedMockContracts();
        
        // Deploy core contracts
        deployContracts();
        
        console.log("Local contract deployment complete");
    }
    
    function deployAdvancedMockContracts() internal {
        console.log("Deploying advanced mock contracts...");
        
        // Deploy mock ERC20 tokens for testing
        address mockSTETH = address(new MockERC20("Liquid staked Ether 2.0", "stETH", 18));
        address mockRETH = address(new MockERC20("Rocket Pool ETH", "rETH", 18));
        address mockCBETH = address(new MockERC20("Coinbase Wrapped Staked ETH", "cbETH", 18));
        address mockWETH = address(new MockERC20("Wrapped Ether", "WETH", 18));
        
        console.log("Mock stETH deployed at:", mockSTETH);
        console.log("Mock rETH deployed at:", mockRETH);
        console.log("Mock cbETH deployed at:", mockCBETH);
        console.log("Mock WETH deployed at:", mockWETH);
        
        // Deploy enhanced mocks for EigenLayer
        if (config.poolManager == address(0)) {
            config.poolManager = address(new AdvancedMockPoolManager());
            console.log("Advanced MockPoolManager deployed at:", config.poolManager);
        }
        
        if (config.avsDirectory == address(0)) {
            config.avsDirectory = address(new AdvancedMockAVSDirectory());
            console.log("Advanced MockAVSDirectory deployed at:", config.avsDirectory);
        }
        
        // Deploy other enhanced mocks
        config.slashingRegistryCoordinator = address(new AdvancedMockSlashingRegistryCoordinator());
        config.stakeRegistry = address(new AdvancedMockStakeRegistry());
        config.rewardsCoordinator = address(new AdvancedMockRewardsCoordinator());
        config.allocationManager = address(new AdvancedMockAllocationManager());
        config.permissionController = address(new AdvancedMockPermissionController());
        config.pauserRegistry = address(new AdvancedMockPauserRegistry());
        
        console.log("All advanced mocks deployed");
    }
    
    function configureLocalContracts() internal {
        console.log("Configuring contracts for local testing...");
        
        // Initialize Service Manager
        YieldSyncServiceManager serviceManager = YieldSyncServiceManager(result.yieldSyncServiceManager);
        serviceManager.initialize(config.deployer, config.deployer);
        
        // Additional local configurations can be added here
        console.log("Local configuration complete");
    }
    
    function setupTestData() internal {
        console.log("Setting up test data for local development...");
        
        // This could include:
        // - Pre-configured pools
        // - Mock yield data
        // - Test positions
        // - Sample transactions
        
        console.log("Test data setup complete");
    }
    
    function logLocalDeploymentResults() internal view {
        console.log("\n=== LOCAL DEPLOYMENT SUMMARY ===");
        console.log("Environment: Local Anvil");
        console.log("Chain ID: 31337");
        console.log("Deployment Block:", result.deploymentBlock);
        console.log("");
        console.log("=== Core Contracts ===");
        console.log("YieldSyncHook:", result.yieldSyncHook);
        console.log("YieldSyncServiceManager:", result.yieldSyncServiceManager);
        console.log("YieldSyncTaskManager:", result.yieldSyncTaskManager);
        console.log("");
        console.log("=== LST Monitors ===");
        console.log("LidoYieldMonitor:", result.lidoYieldMonitor);
        console.log("RocketPoolMonitor:", result.rocketPoolMonitor);
        console.log("CoinbaseMonitor:", result.coinbaseMonitor);
        console.log("FraxMonitor:", result.fraxMonitor);
        console.log("");
        console.log("=== Infrastructure ===");
        console.log("PoolManager (Mock):", config.poolManager);
        console.log("AVSDirectory (Mock):", config.avsDirectory);
        console.log("");
        console.log("=== Usage Instructions ===");
        console.log("1. Run tests: forge test");
        console.log("2. Interact via cast: cast call <address> <signature>");
        console.log("3. Check deployment: cat deployments/Anvil.json");
        console.log("===============================");
    }
    
    function saveLocalDeploymentAddresses() internal {
        // Save standard deployment file
        saveDeploymentAddresses();
        
        // Save additional local development file with extra info
        string memory json = "localDeployment";
        
        // Core contracts
        vm.serializeAddress(json, "yieldSyncHook", result.yieldSyncHook);
        vm.serializeAddress(json, "yieldSyncServiceManager", result.yieldSyncServiceManager);
        vm.serializeAddress(json, "yieldSyncTaskManager", result.yieldSyncTaskManager);
        
        // LST Monitors
        vm.serializeAddress(json, "lidoYieldMonitor", result.lidoYieldMonitor);
        vm.serializeAddress(json, "rocketPoolMonitor", result.rocketPoolMonitor);
        vm.serializeAddress(json, "coinbaseMonitor", result.coinbaseMonitor);
        vm.serializeAddress(json, "fraxMonitor", result.fraxMonitor);
        
        // Mock infrastructure
        vm.serializeAddress(json, "poolManager", config.poolManager);
        vm.serializeAddress(json, "avsDirectory", config.avsDirectory);
        vm.serializeAddress(json, "slashingRegistryCoordinator", config.slashingRegistryCoordinator);
        vm.serializeAddress(json, "stakeRegistry", config.stakeRegistry);
        vm.serializeAddress(json, "rewardsCoordinator", config.rewardsCoordinator);
        vm.serializeAddress(json, "allocationManager", config.allocationManager);
        vm.serializeAddress(json, "permissionController", config.permissionController);
        vm.serializeAddress(json, "pauserRegistry", config.pauserRegistry);
        
        // Metadata
        vm.serializeString(json, "network", "anvil");
        vm.serializeUint(json, "chainId", 31337);
        vm.serializeUint(json, "deploymentBlock", result.deploymentBlock);
        vm.serializeUint(json, "timestamp", block.timestamp);
        string memory finalJson = vm.serializeAddress(json, "deployer", config.deployer);
        
        vm.writeJson(finalJson, "deployments/anvil-local.json");
        console.log("Local deployment data saved to: deployments/anvil-local.json");
    }
}

// Advanced Mock Contracts for Local Development

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        
        // Mint initial supply to deployer
        uint256 initialSupply = 1000000 * 10**_decimals;
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }
}

contract AdvancedMockPoolManager {
    mapping(bytes32 => bool) public pools;
    
    function initialize(address, uint160) external pure returns (bytes4) {
        return this.initialize.selector;
    }
    
    function createPool(address token0, address token1, uint24 fee) external returns (bytes32 poolId) {
        poolId = keccak256(abi.encodePacked(token0, token1, fee));
        pools[poolId] = true;
    }
    
    function getPool(bytes32 poolId) external view returns (bool exists) {
        return pools[poolId];
    }
}

contract AdvancedMockAVSDirectory {
    mapping(address => string) public avsMetadataURIs;
    
    function updateAVSMetadataURI(string calldata metadataURI) external {
        avsMetadataURIs[msg.sender] = metadataURI;
    }
    
    function getAVSMetadataURI(address avs) external view returns (string memory) {
        return avsMetadataURIs[avs];
    }
}

contract AdvancedMockSlashingRegistryCoordinator {
    mapping(address => bool) public registeredOperators;
    address public stakeRegistry;
    address public blsApkRegistry;
    
    constructor() {
        stakeRegistry = address(0x1234567890123456789012345678901234567890); // Mock address
        blsApkRegistry = address(0x2345678901234567890123456789012345678901); // Mock address
    }
    
    function registerOperator(address operator) external {
        registeredOperators[operator] = true;
    }
    
    function isOperatorRegistered(address operator) external view returns (bool) {
        return registeredOperators[operator];
    }
}

contract AdvancedMockStakeRegistry {
    mapping(address => uint256) public operatorStakes;
    
    function updateOperatorStake(address operator, uint256 stake) external {
        operatorStakes[operator] = stake;
    }
    
    function getOperatorStake(address operator) external view returns (uint256) {
        return operatorStakes[operator];
    }
}

contract AdvancedMockRewardsCoordinator {
    mapping(address => uint256) public rewards;
    
    function distributeRewards(address recipient, uint256 amount) external {
        rewards[recipient] += amount;
    }
    
    function getRewards(address recipient) external view returns (uint256) {
        return rewards[recipient];
    }
}

contract AdvancedMockAllocationManager {
    mapping(address => uint256) public allocations;
    
    function setAllocation(address operator, uint256 amount) external {
        allocations[operator] = amount;
    }
    
    function getAllocation(address operator) external view returns (uint256) {
        return allocations[operator];
    }
}

contract AdvancedMockPermissionController {
    mapping(address => mapping(bytes4 => bool)) public permissions;
    
    function setPermission(address account, bytes4 functionSelector, bool allowed) external {
        permissions[account][functionSelector] = allowed;
    }
    
    function hasPermission(address account, bytes4 functionSelector) external view returns (bool) {
        return permissions[account][functionSelector];
    }
}

contract AdvancedMockPauserRegistry {
    mapping(address => bool) public pausers;
    bool public isPaused;
    
    function addPauser(address pauser) external {
        pausers[pauser] = true;
    }
    
    function pause() external {
        require(pausers[msg.sender], "Not authorized to pause");
        isPaused = true;
    }
    
    function unpause() external {
        require(pausers[msg.sender], "Not authorized to unpause");
        isPaused = false;
    }
}