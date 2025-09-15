// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Deploy.s.sol";

/**
 * @title DeployTestnet
 * @dev Specialized deployment script for testnets (Goerli, Sepolia, Holesky)
 */
contract DeployTestnet is Deploy {
    
    bool public verifyContracts = true;
    uint256 public constant VERIFICATION_DELAY = 30; // seconds
    
    function run() external override {
        uint256 chainId = block.chainid;
        string memory networkName = getNetworkName(chainId);
        
        console.log("=== YieldSync Hook - Testnet Deployment ===");
        console.log("Network:", networkName);
        console.log("Chain ID:", chainId);
        
        require(chainId != 1, "Use DeployMainnet script for mainnet");
        require(chainId != 31337, "Use DeployAnvil script for local development");
        
        // Load testnet configuration
        loadNetworkConfig(chainId);
        
        // Validate environment variables
        validateTestnetEnvironment();
        
        vm.startBroadcast();
        
        // Deploy contracts with testnet-specific settings
        deployTestnetContracts();
        
        // Configure for testnet
        configureTestnetContracts();
        
        // Setup testnet-specific data
        setupTestnetData();
        
        vm.stopBroadcast();
        
        // Verify contracts on etherscan
        if (verifyContracts) {
            verifyDeployedContracts();
        }
        
        // Log and save results
        logTestnetDeploymentResults();
        saveTestnetDeploymentAddresses();
        
        // Provide next steps
        provideTestnetInstructions();
        
        console.log("=== Testnet Deployment Complete ===");
    }
    
    function getNetworkName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 5) return "Goerli";
        if (chainId == 11155111) return "Sepolia";
        if (chainId == 17000) return "Holesky";
        revert("Unsupported testnet");
    }
    
    function validateTestnetEnvironment() internal view {
        require(config.deployer != address(0), "DEPLOYER_PRIVATE_KEY_ADDRESS not set");
        
        // Check deployer has sufficient funds
        uint256 deployerBalance = config.deployer.balance;
        uint256 minimumBalance = 0.1 ether;
        require(deployerBalance >= minimumBalance, "Insufficient deployer balance");
        
        console.log("Deployer balance:", deployerBalance / 1e18, "ETH");
        console.log("Validation passed");
    }
    
    function deployTestnetContracts() internal {
        console.log("=== Deploying Contracts for Testnet ===");
        
        // For testnets, we may need to deploy some mocks if infrastructure isn't available
        deployTestnetMockContracts();
        
        // Deploy main contracts
        deployContracts();
        
        console.log("Testnet contract deployment complete");
    }
    
    function deployTestnetMockContracts() internal {
        console.log("Deploying testnet-specific mocks where needed...");
        
        // Deploy mock contracts for missing infrastructure
        if (config.poolManager == address(0)) {
            config.poolManager = address(new TestnetMockPoolManager());
            console.log("Testnet MockPoolManager deployed at:", config.poolManager);
        }
        
        if (config.avsDirectory == address(0)) {
            config.avsDirectory = address(new TestnetMockAVSDirectory());
            console.log("Testnet MockAVSDirectory deployed at:", config.avsDirectory);
        }
        
        // Deploy enhanced mocks for testing
        if (config.slashingRegistryCoordinator == address(0)) {
            config.slashingRegistryCoordinator = address(new TestnetMockSlashingRegistryCoordinator());
        }
        
        if (config.stakeRegistry == address(0)) {
            config.stakeRegistry = address(new TestnetMockStakeRegistry());
        }
        
        if (config.rewardsCoordinator == address(0)) {
            config.rewardsCoordinator = address(new TestnetMockRewardsCoordinator());
        }
        
        if (config.allocationManager == address(0)) {
            config.allocationManager = address(new TestnetMockAllocationManager());
        }
        
        if (config.permissionController == address(0)) {
            config.permissionController = address(new TestnetMockPermissionController());
        }
        
        if (config.pauserRegistry == address(0)) {
            config.pauserRegistry = address(new TestnetMockPauserRegistry());
        }
        
        console.log("Testnet mocks deployed");
    }
    
    function configureTestnetContracts() internal {
        console.log("Configuring contracts for testnet...");
        
        // Initialize Service Manager
        YieldSyncServiceManager serviceManager = YieldSyncServiceManager(result.yieldSyncServiceManager);
        serviceManager.initialize(config.deployer, config.deployer);
        
        // Additional testnet-specific configurations
        console.log("Testnet configuration complete");
    }
    
    function setupTestnetData() internal {
        console.log("Setting up testnet-specific data...");
        
        // Deploy test tokens if needed
        address testSTETH = deployTestToken("Test Lido Staked ETH", "tstETH");
        address testRETH = deployTestToken("Test Rocket Pool ETH", "trETH");
        address testWETH = deployTestToken("Test Wrapped ETH", "tWETH");
        
        console.log("Test tokens deployed:");
        console.log("  tstETH:", testSTETH);
        console.log("  trETH:", testRETH);
        console.log("  tWETH:", testWETH);
        
        console.log("Testnet data setup complete");
    }
    
    function deployTestToken(string memory name, string memory symbol) internal returns (address) {
        TestToken token = new TestToken(name, symbol);
        
        // Mint initial supply for testing
        token.mint(config.deployer, 1000000 * 1e18);
        
        return address(token);
    }
    
    function verifyDeployedContracts() internal {
        console.log("Starting contract verification...");
        console.log("Waiting", VERIFICATION_DELAY, "seconds before verification...");
        
        // Wait for block confirmations
        vm.sleep(VERIFICATION_DELAY * 1000);
        
        // Note: Actual verification would use forge verify-contract
        // This is a placeholder for the verification process
        console.log("Contract verification initiated");
        console.log("Run the following commands to verify contracts:");
        console.log("");
        
        console.log("forge verify-contract", result.yieldSyncHook, "src/hooks/YieldSyncHook.sol:YieldSyncHook");
        console.log("forge verify-contract", result.yieldSyncServiceManager, "src/avs/YieldSyncServiceManager.sol:YieldSyncServiceManager");
        console.log("forge verify-contract", result.yieldSyncTaskManager, "src/avs/YieldSyncTaskManager.sol:YieldSyncTaskManager");
        console.log("forge verify-contract", result.lidoYieldMonitor, "src/avs/LSTMonitors/LidoYieldMonitor.sol:LidoYieldMonitor");
        console.log("");
    }
    
    function logTestnetDeploymentResults() internal view {
        console.log("\n=== TESTNET DEPLOYMENT SUMMARY ===");
        console.log("Network:", result.networkName);
        console.log("Chain ID:", block.chainid);
        console.log("Deployment Block:", result.deploymentBlock);
        console.log("Deployer:", config.deployer);
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
        console.log("=== Infrastructure (Mocks) ===");
        console.log("PoolManager:", config.poolManager);
        console.log("AVSDirectory:", config.avsDirectory);
        console.log("SlashingRegistryCoordinator:", config.slashingRegistryCoordinator);
        console.log("StakeRegistry:", config.stakeRegistry);
        console.log("====================================");
    }
    
    function saveTestnetDeploymentAddresses() internal {
        // Save standard deployment file
        saveDeploymentAddresses();
        
        // Save testnet-specific deployment info
        string memory json = "testnetDeployment";
        
        // All contract addresses
        vm.serializeAddress(json, "yieldSyncHook", result.yieldSyncHook);
        vm.serializeAddress(json, "yieldSyncServiceManager", result.yieldSyncServiceManager);
        vm.serializeAddress(json, "yieldSyncTaskManager", result.yieldSyncTaskManager);
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
        
        // Metadata
        vm.serializeString(json, "network", result.networkName);
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeUint(json, "deploymentBlock", result.deploymentBlock);
        vm.serializeUint(json, "timestamp", block.timestamp);
        vm.serializeAddress(json, "deployer", config.deployer);
        string memory finalJson = vm.serializeBool(json, "verified", verifyContracts);
        
        string memory filename = string.concat("deployments/testnet-", result.networkName, ".json");
        vm.writeJson(finalJson, filename);
        console.log("Testnet deployment data saved to:", filename);
    }
    
    function provideTestnetInstructions() internal view {
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Verify contracts on Etherscan (commands provided above)");
        console.log("2. Update frontend configuration with new addresses");
        console.log("3. Run integration tests against testnet deployment");
        console.log("4. Configure pools using the configurePool function");
        console.log("5. Test with testnet LST tokens");
        console.log("");
        console.log("=== Testing Commands ===");
        console.log("Run tests: forge test --fork-url <TESTNET_RPC_URL>");
        console.log("Interact: cast call <ADDRESS> <FUNCTION> --rpc-url <TESTNET_RPC_URL>");
        console.log("");
        console.log("=== Deployment Files ===");
        console.log("Standard: deployments/", result.networkName, ".json");
        console.log("Detailed: deployments/testnet-", result.networkName, ".json");
        console.log("==================");
    }
}

// Enhanced Mock Contracts for Testnet

contract TestToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        require(balanceOf[from] >= amount, "Insufficient balance");
        
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}

// Testnet-specific mock contracts with enhanced functionality

contract TestnetMockPoolManager {
    struct Pool {
        address token0;
        address token1;
        uint24 fee;
        bool exists;
    }
    
    mapping(bytes32 => Pool) public pools;
    bytes32[] public poolIds;
    
    event PoolCreated(bytes32 indexed poolId, address token0, address token1, uint24 fee);
    
    function initialize(address, uint160) external pure returns (bytes4) {
        return this.initialize.selector;
    }
    
    function createPool(address token0, address token1, uint24 fee) external returns (bytes32 poolId) {
        require(token0 != token1, "Identical tokens");
        
        poolId = keccak256(abi.encodePacked(token0, token1, fee));
        require(!pools[poolId].exists, "Pool already exists");
        
        pools[poolId] = Pool({
            token0: token0,
            token1: token1,
            fee: fee,
            exists: true
        });
        
        poolIds.push(poolId);
        emit PoolCreated(poolId, token0, token1, fee);
    }
    
    function getPool(bytes32 poolId) external view returns (Pool memory) {
        return pools[poolId];
    }
    
    function getPoolCount() external view returns (uint256) {
        return poolIds.length;
    }
}

contract TestnetMockAVSDirectory {
    mapping(address => string) public avsMetadataURIs;
    mapping(address => bool) public registeredAVS;
    
    event AVSRegistered(address indexed avs, string metadataURI);
    event AVSMetadataURIUpdated(address indexed avs, string metadataURI);
    
    function registerAVS(string calldata metadataURI) external {
        registeredAVS[msg.sender] = true;
        avsMetadataURIs[msg.sender] = metadataURI;
        emit AVSRegistered(msg.sender, metadataURI);
    }
    
    function updateAVSMetadataURI(string calldata metadataURI) external {
        require(registeredAVS[msg.sender], "AVS not registered");
        avsMetadataURIs[msg.sender] = metadataURI;
        emit AVSMetadataURIUpdated(msg.sender, metadataURI);
    }
    
    function isAVSRegistered(address avs) external view returns (bool) {
        return registeredAVS[avs];
    }
}

contract TestnetMockSlashingRegistryCoordinator {
    mapping(address => bool) public registeredOperators;
    mapping(address => uint256) public operatorStakes;
    address[] public operators;
    
    event OperatorRegistered(address indexed operator);
    event OperatorStakeUpdated(address indexed operator, uint256 newStake);
    
    function registerOperator(address operator, uint256 initialStake) external {
        require(!registeredOperators[operator], "Already registered");
        registeredOperators[operator] = true;
        operatorStakes[operator] = initialStake;
        operators.push(operator);
        emit OperatorRegistered(operator);
        emit OperatorStakeUpdated(operator, initialStake);
    }
    
    function updateOperatorStake(address operator, uint256 newStake) external {
        require(registeredOperators[operator], "Not registered");
        operatorStakes[operator] = newStake;
        emit OperatorStakeUpdated(operator, newStake);
    }
    
    function getOperatorCount() external view returns (uint256) {
        return operators.length;
    }
}

contract TestnetMockStakeRegistry {
    mapping(address => uint256) public operatorStakes;
    uint256 public totalStake;
    
    function updateOperatorStake(address operator, uint256 stake) external {
        uint256 oldStake = operatorStakes[operator];
        operatorStakes[operator] = stake;
        totalStake = totalStake - oldStake + stake;
    }
}

contract TestnetMockRewardsCoordinator {
    mapping(address => uint256) public rewards;
    uint256 public totalRewards;
    
    function distributeRewards(address recipient, uint256 amount) external {
        rewards[recipient] += amount;
        totalRewards += amount;
    }
    
    function claimRewards() external {
        uint256 amount = rewards[msg.sender];
        rewards[msg.sender] = 0;
        totalRewards -= amount;
        // In a real implementation, this would transfer tokens
    }
}

contract TestnetMockAllocationManager {
    mapping(address => uint256) public allocations;
    
    function setAllocation(address operator, uint256 amount) external {
        allocations[operator] = amount;
    }
}

contract TestnetMockPermissionController {
    mapping(address => mapping(bytes4 => bool)) public permissions;
    
    function setPermission(address account, bytes4 functionSelector, bool allowed) external {
        permissions[account][functionSelector] = allowed;
    }
    
    function hasPermission(address account, bytes4 functionSelector) external view returns (bool) {
        return permissions[account][functionSelector];
    }
}

contract TestnetMockPauserRegistry {
    mapping(address => bool) public pausers;
    bool public isPaused;
    
    event Paused();
    event Unpaused();
    event PauserAdded(address pauser);
    
    constructor() {
        pausers[msg.sender] = true;
        emit PauserAdded(msg.sender);
    }
    
    function addPauser(address pauser) external {
        pausers[pauser] = true;
        emit PauserAdded(pauser);
    }
    
    function pause() external {
        require(pausers[msg.sender], "Not authorized");
        isPaused = true;
        emit Paused();
    }
    
    function unpause() external {
        require(pausers[msg.sender], "Not authorized");
        isPaused = false;
        emit Unpaused();
    }
}