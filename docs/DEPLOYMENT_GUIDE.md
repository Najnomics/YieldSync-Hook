# YieldSync Hook Deployment Guide

This guide provides comprehensive instructions for deploying the YieldSync Hook system across different networks.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Local Development (Anvil)](#local-development-anvil)
4. [Testnet Deployment](#testnet-deployment)
5. [Mainnet Deployment](#mainnet-deployment)
6. [Post-Deployment](#post-deployment)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (latest version)
- [Node.js](https://nodejs.org/) (v16 or later)
- [Git](https://git-scm.com/)

### Required Accounts

- Ethereum wallet with sufficient funds
- [Etherscan API key](https://etherscan.io/apis) (for verification)
- [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/) RPC endpoints

## Environment Setup

### 1. Clone and Setup Repository

```bash
git clone <repository-url>
cd YieldSync-Hook
forge install
forge build
```

### 2. Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit the .env file with your values
nano .env  # or use your preferred editor
```

### 3. Required Environment Variables

**Essential Variables:**
```env
PRIVATE_KEY=your_private_key_without_0x_prefix
DEPLOYER_PRIVATE_KEY_ADDRESS=0x_your_address
MAINNET_RPC_URL=your_rpc_endpoint
ETHERSCAN_API_KEY=your_etherscan_api_key
```

**Network-Specific Variables:**
- See `.env.example` for complete list
- Update RPC URLs for your preferred providers
- Set appropriate gas prices for each network

## Local Development (Anvil)

### 1. Start Local Node

```bash
# Terminal 1: Start Anvil
anvil

# Note the default accounts and private keys shown
```

### 2. Deploy to Local Network

```bash
# Terminal 2: Deploy contracts
forge script script/DeployAnvil.s.sol:DeployAnvil --fork-url http://127.0.0.1:8545 --broadcast -vvvv

# Check deployment
cat deployments/anvil-local.json
```

### 3. Run Tests Against Local Deployment

```bash
# Run all tests
forge test --fork-url http://127.0.0.1:8545 -vvv

# Run specific test file
forge test --match-path test/YieldSyncHook.t.sol --fork-url http://127.0.0.1:8545 -vvv

# Get coverage report
forge coverage --fork-url http://127.0.0.1:8545
```

### 4. Interact with Local Contracts

```bash
# Example: Check hook owner
cast call <HOOK_ADDRESS> "owner()" --rpc-url http://127.0.0.1:8545

# Example: Configure a pool
cast send <HOOK_ADDRESS> "configurePool((bytes32,(address,address,bool,uint256,bool)))" \
  <POOL_ID> \
  "(<LST_TOKEN>,<PAIRED_TOKEN>,true,50,true)" \
  --private-key <PRIVATE_KEY> \
  --rpc-url http://127.0.0.1:8545
```

## Testnet Deployment

### Supported Testnets

- **Holesky** (Recommended - EigenLayer testnet)
- **Sepolia** 
- **Goerli** (Deprecated but supported)

### 1. Pre-Deployment Checklist

- [ ] Sufficient testnet ETH (get from faucets)
- [ ] RPC endpoint configured
- [ ] Private key and address set
- [ ] Etherscan API key (for verification)

### 2. Deploy to Testnet

#### Holesky (Recommended)

```bash
# Deploy to Holesky testnet
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url $HOLESKY_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

#### Sepolia

```bash
# Deploy to Sepolia
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

### 3. Verify Deployment

```bash
# Check deployment files
cat deployments/Holesky.json
cat deployments/testnet-Holesky.json

# Verify a contract manually (if auto-verification failed)
forge verify-contract <CONTRACT_ADDRESS> src/hooks/YieldSyncHook.sol:YieldSyncHook \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain-id 17000
```

### 4. Test on Testnet

```bash
# Run integration tests against testnet
forge test --fork-url $HOLESKY_RPC_URL --match-contract IntegrationTest -vvv

# Test specific functionality
cast call <HOOK_ADDRESS> "getHookPermissions()" --rpc-url $HOLESKY_RPC_URL
```

## Mainnet Deployment

> ⚠️ **WARNING**: Mainnet deployment uses real ETH and creates immutable contracts. Double-check all configurations!

### 1. Pre-Deployment Checklist

- [ ] **Minimum 1 ETH** in deployer account
- [ ] All configurations thoroughly tested on testnet
- [ ] Smart contract audit completed
- [ ] Deployment parameters reviewed by team
- [ ] Mainnet RPC endpoint configured
- [ ] Etherscan API key set
- [ ] Emergency procedures documented

### 2. Mainnet Deployment Command

```bash
# Deploy to Ethereum Mainnet (PRODUCTION)
forge script script/DeployMainnet.s.sol:DeployMainnet \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --gas-price 20000000000 \
  -vvvv
```

### 3. Mainnet Safety Features

The mainnet deployment script includes:

- **Balance checks**: Ensures minimum ETH balance
- **Network validation**: Confirms deployment to mainnet
- **Deployment delays**: Built-in delays between critical deployments
- **Post-deployment validation**: Automated checks after deployment
- **Comprehensive logging**: Detailed deployment logs
- **Multiple backup files**: Redundant storage of deployment data

### 4. Post-Mainnet Deployment

1. **Immediate Actions**:
   ```bash
   # Verify all contracts on Etherscan
   # (Commands provided in deployment output)
   
   # Update frontend configuration
   cp deployments/mainnet.json frontend/src/config/
   
   # Notify team members
   # Post deployment addresses in team channels
   ```

2. **Configuration Tasks**:
   ```bash
   # Configure pools with LST tokens
   cast send <HOOK_ADDRESS> "configurePool((bytes32,(address,address,bool,uint256,bool)))" \
     <POOL_ID> \
     "(<STETH_ADDRESS>,<WETH_ADDRESS>,true,50,true)" \
     --private-key $PRIVATE_KEY \
     --rpc-url $MAINNET_RPC_URL \
     --gas-price 20000000000
   ```

## Post-Deployment

### 1. Contract Verification

If auto-verification fails, verify manually:

```bash
# YieldSync Hook
forge verify-contract <HOOK_ADDRESS> src/hooks/YieldSyncHook.sol:YieldSyncHook \
  --constructor-args $(cast abi-encode "constructor(address,address)" <POOL_MANAGER> <SERVICE_MANAGER>) \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Service Manager  
forge verify-contract <SERVICE_MANAGER_ADDRESS> src/avs/YieldSyncServiceManager.sol:YieldSyncServiceManager \
  --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,address,address)" \
    <AVS_DIRECTORY> <SLASHING_COORDINATOR> <STAKE_REGISTRY> <REWARDS_COORDINATOR> \
    <ALLOCATION_MANAGER> <PERMISSION_CONTROLLER> <TASK_MANAGER>) \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 2. Integration Testing

```bash
# Run comprehensive integration tests
forge test --match-contract IntegrationTest --fork-url $MAINNET_RPC_URL -vvv

# Test hook permissions
cast call <HOOK_ADDRESS> "getHookPermissions()" --rpc-url $MAINNET_RPC_URL

# Test position health check (requires configured pool and position)
cast call <HOOK_ADDRESS> "getPositionHealth(bytes32)" <POSITION_ID> --rpc-url $MAINNET_RPC_URL
```

### 3. Monitoring Setup

1. **Contract Monitoring**:
   - Set up Etherscan alerts for all deployed contracts
   - Monitor for failed transactions
   - Track gas usage patterns

2. **Business Logic Monitoring**:
   - Monitor position adjustments
   - Track yield rate changes
   - Alert on unusual activity

### 4. Documentation Updates

1. Update README.md with deployed addresses
2. Update API documentation with contract interfaces
3. Create user guides for interacting with the system
4. Document operational procedures

## Troubleshooting

### Common Issues

#### 1. Insufficient Gas

**Error**: `Transaction reverted: out of gas`

**Solution**:
```bash
# Increase gas limit
--gas-limit 20000000

# Or set higher gas price
--gas-price 30000000000
```

#### 2. Verification Fails

**Error**: `Contract verification failed`

**Solutions**:
1. Wait longer before verifying (network delays)
2. Verify manually with exact constructor arguments
3. Check if contract already verified
4. Ensure correct compiler version in foundry.toml

#### 3. RPC Endpoint Issues

**Error**: `Connection refused` or `Rate limited`

**Solutions**:
1. Use different RPC provider
2. Add API key to RPC URL
3. Reduce request frequency
4. Check network status

#### 4. Private Key Issues

**Error**: `Invalid private key format`

**Solutions**:
1. Remove `0x` prefix from private key
2. Ensure private key is exactly 64 characters
3. Verify address matches private key
4. Check environment variable loading

### Emergency Procedures

#### 1. Failed Deployment

If deployment fails partway through:

1. **Do not retry immediately**
2. Check which contracts deployed successfully
3. Analyze failure reason from logs  
4. If safe, continue from failed point
5. Otherwise, plan full redeployment

#### 2. Wrong Configuration

If contracts deployed with wrong config:

1. **Cannot change immutable parameters**
2. For ownership/admin functions, use existing admin functions
3. For major errors, may need full redeployment
4. Document issue and resolution

#### 3. Security Issues

If security vulnerability discovered:

1. **Immediately pause all pausable contracts**
2. Notify users through all channels
3. Coordinate response with security team
4. Plan upgrade/migration strategy

### Getting Help

1. **Documentation**: Check this guide and contract documentation
2. **Logs**: Always use `-vvvv` for detailed logs
3. **Community**: Reach out to Foundry/EigenLayer communities
4. **Code Review**: Have deployments reviewed by team members

---

## Deployment Checklist

### Pre-Deployment
- [ ] Environment variables configured
- [ ] Sufficient funds in deployer account  
- [ ] Contracts compiled successfully
- [ ] Tests passing
- [ ] Network configuration verified

### During Deployment
- [ ] Monitor deployment progress
- [ ] Save all logs and outputs
- [ ] Verify each contract deployment
- [ ] Check deployment files created

### Post-Deployment
- [ ] Verify contracts on Etherscan
- [ ] Update configuration files
- [ ] Run integration tests
- [ ] Set up monitoring
- [ ] Notify stakeholders
- [ ] Document deployment

### Mainnet Only
- [ ] Security audit completed
- [ ] Multi-sig setup (if applicable)
- [ ] Emergency procedures documented
- [ ] Team coordination complete
- [ ] User communication prepared

---

*For additional support or questions about deployment, refer to the project documentation or contact the development team.*