# Quick Start Guide

Get up and running with YieldSync Hook in under 10 minutes.

## Prerequisites

- Foundry installed
- Go 1.21+ installed
- Node.js 18+ installed

## 1. Clone and Setup

```bash
# Clone the repository
git clone --recursive https://github.com/your-org/yieldsync-hook.git
cd yieldsync-hook

# Install dependencies
make install

# Copy environment file
cp .env.example .env
```

## 2. Start Local Development

```bash
# Start Anvil (in one terminal)
make start-anvil

# Deploy contracts (in another terminal)
make deploy-local

# Run tests
make test
```

## 3. Explore the Contracts

### Main Contracts

- **YieldSyncHook**: Main Uniswap V4 hook contract
- **YieldSyncServiceManager**: EigenLayer AVS service manager
- **YieldSyncTaskManager**: Task coordination and management

### LST Monitors

- **LidoYieldMonitor**: Monitors stETH yield
- **RocketPoolMonitor**: Monitors rETH yield
- **CoinbaseMonitor**: Monitors cbETH yield
- **FraxMonitor**: Monitors sfrxETH yield

## 4. Test the System

```bash
# Run unit tests
forge test --match-contract YieldSyncHookTest

# Run integration tests
forge test --match-path "test/integration/*"

# Run fuzz tests
forge test --match-test "testFuzz"

# Check coverage
forge coverage --ir-minimum
```

## 5. Interact with Contracts

### Using Cast

```bash
# Get contract address from deployment
cat deployments/anvil-local.json

# Call a view function
cast call <HOOK_ADDRESS> "getPositionHealth(bytes32)" <POSITION_ID> --rpc-url http://localhost:8545

# Send a transaction
cast send <HOOK_ADDRESS> "manuallyAdjustPosition(bytes32)" <POSITION_ID> --private-key <PRIVATE_KEY> --rpc-url http://localhost:8545
```

### Using Foundry Scripts

```bash
# Run deployment script
forge script script/DeployAnvil.s.sol:DeployAnvil --rpc-url http://localhost:8545 --broadcast

# Run interaction script
forge script script/InteractWithHook.s.sol:InteractWithHook --rpc-url http://localhost:8545 --broadcast
```

## 6. Deploy to Testnet

```bash
# Set up testnet environment
export HOLESKY_RPC_URL="your_holesky_rpc_url"
export TESTNET_PRIVATE_KEY="your_private_key"
export ETHERSCAN_API_KEY="your_etherscan_key"

# Deploy to Holesky
make deploy-sepolia

# Verify contracts
forge verify-contract <ADDRESS> <CONTRACT_NAME> --etherscan-api-key $ETHERSCAN_API_KEY --chain holesky
```

## 7. Monitor and Debug

### View Logs

```bash
# Check deployment logs
cat deployments/anvil-local.json

# View test output
forge test -vvv

# Check gas usage
forge test --gas-report
```

### Debug Common Issues

```bash
# Check if Anvil is running
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545

# Verify contract deployment
cast code <CONTRACT_ADDRESS> --rpc-url http://localhost:8545

# Check contract state
cast call <CONTRACT_ADDRESS> "owner()" --rpc-url http://localhost:8545
```

## 8. Next Steps

### Development

1. **Read the Architecture**: [Hook Architecture](HOOK_ARCHITECTURE.md)
2. **Understand AVS Integration**: [AVS Integration](AVS_INTEGRATION.md)
3. **Explore Examples**: Check `examples/` directory
4. **Run Integration Tests**: `forge test --match-path "test/integration/*"`

### Production

1. **Security Review**: [Security Guide](SECURITY.md)
2. **Deployment Guide**: [Deployment Guide](DEPLOYMENT_GUIDE.md)
3. **Monitoring Setup**: [Monitoring Guide](MONITORING.md)
4. **Operator Setup**: [Operator Guide](OPERATOR_GUIDE.md)

## Common Commands

```bash
# Build
make build

# Test
make test

# Deploy locally
make deploy-local

# Deploy to testnet
make deploy-sepolia

# Deploy to mainnet
make deploy-mainnet

# Clean
make clean

# Format code
make format

# Lint
make lint

# Coverage
forge coverage --ir-minimum
```

## Getting Help

- **Documentation**: Check the `docs/` directory
- **Issues**: [GitHub Issues](https://github.com/your-org/yieldsync-hook/issues)
- **Discord**: [Join our community](https://discord.gg/yieldsync)
- **Email**: team@yieldsync.xyz

## Troubleshooting

### Contract Deployment Fails

```bash
# Check Anvil is running
ps aux | grep anvil

# Restart Anvil
pkill anvil
make start-anvil

# Check gas limit
cast block --rpc-url http://localhost:8545
```

### Tests Fail

```bash
# Run with verbose output
forge test -vvv

# Run specific test
forge test --match-test "testSpecificFunction"

# Check test setup
forge test --match-contract "TestSetup"
```

### Build Issues

```bash
# Clean and rebuild
make clean
make build

# Check Solidity version
forge --version

# Verify dependencies
forge install --no-commit
```

## Success!

If you've completed all steps successfully, you should have:

✅ A working local development environment  
✅ All contracts deployed and tested  
✅ Understanding of the system architecture  
✅ Ability to interact with contracts  
✅ Ready for further development or production deployment  

Welcome to YieldSync Hook development! 🚀
