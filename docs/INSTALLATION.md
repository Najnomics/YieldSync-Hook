# Installation Guide

This guide will help you install and set up the YieldSync Hook project for development and production use.

## Prerequisites

### Required Software

- **Foundry**: For Solidity development and testing
- **Go 1.21+**: For AVS operator components
- **Node.js 18+**: For frontend and tooling
- **Git**: For version control

### System Requirements

- **OS**: Linux, macOS, or Windows (WSL recommended)
- **RAM**: Minimum 8GB, 16GB recommended
- **Storage**: At least 10GB free space
- **Network**: Stable internet connection for dependency downloads

## Installation Steps

### 1. Install Foundry

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
forge --version
cast --version
anvil --version
```

### 2. Install Go

```bash
# On macOS with Homebrew
brew install go

# On Ubuntu/Debian
sudo apt update
sudo apt install golang-go

# On Windows (using Chocolatey)
choco install golang

# Verify installation
go version
```

### 3. Install Node.js

```bash
# Using Node Version Manager (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 18
nvm use 18

# Or download from nodejs.org
# Verify installation
node --version
npm --version
```

### 4. Clone the Repository

```bash
# Clone with submodules
git clone --recursive https://github.com/your-org/yieldsync-hook.git
cd yieldsync-hook

# Or if already cloned, update submodules
git submodule update --init --recursive
```

### 5. Install Dependencies

```bash
# Install Solidity dependencies
make install

# Install AVS dependencies
cd avs && npm install && cd ..

# Install additional tooling
npm install -g @foundry-rs/forge
```

### 6. Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env
# or
code .env
```

### 7. Build the Project

```bash
# Build all contracts
make build

# Verify build
ls out/
```

### 8. Run Tests

```bash
# Run all tests
make test

# Run with coverage
forge coverage --ir-minimum

# Run specific test suites
forge test --match-contract YieldSyncHookTest
forge test --match-path "test/integration/*"
```

## Development Setup

### Local Development Environment

```bash
# Start local Anvil chain
make start-anvil

# In another terminal, deploy contracts
make deploy-local

# Run tests against local deployment
forge test --fork-url http://localhost:8545
```

### IDE Setup

#### VS Code

1. Install the following extensions:
   - Solidity (Juan Blanco)
   - Hardhat Solidity (Nomic Foundation)
   - Go (Google)

2. Configure settings in `.vscode/settings.json`:

```json
{
  "solidity.compileUsingRemoteVersion": "v0.8.27",
  "solidity.defaultCompiler": "remote",
  "go.toolsManagement.checkForUpdates": "local"
}
```

#### IntelliJ IDEA

1. Install Solidity plugin
2. Configure Go SDK
3. Set up Foundry integration

## Production Setup

### Environment Configuration

1. **Set up RPC endpoints**:
   - Mainnet: Use Alchemy, Infura, or your own node
   - Testnet: Use public RPC or your own testnet node

2. **Configure API keys**:
   - Etherscan for contract verification
   - LST protocol APIs for yield data
   - Monitoring and alerting services

3. **Set up monitoring**:
   - Configure logging
   - Set up alerting
   - Monitor gas costs

### Deployment

```bash
# Deploy to testnet
make deploy-sepolia

# Deploy to mainnet (with caution)
make deploy-mainnet

# Verify contracts
forge verify-contract <ADDRESS> <CONTRACT_NAME>
```

## Troubleshooting

### Common Issues

#### Foundry Installation Issues

```bash
# If foundryup fails
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

#### Go Module Issues

```bash
# Clean module cache
go clean -modcache

# Re-download dependencies
go mod download
```

#### Node.js Version Issues

```bash
# Use correct Node.js version
nvm use 18

# Clear npm cache
npm cache clean --force
```

#### Submodule Issues

```bash
# Reset submodules
git submodule deinit --all -f
git submodule update --init --recursive
```

### Getting Help

- Check the [troubleshooting section](TROUBLESHOOTING.md)
- Review [GitHub issues](https://github.com/your-org/yieldsync-hook/issues)
- Join our [Discord community](https://discord.gg/yieldsync)

## Next Steps

After installation:

1. Read the [Quick Start Guide](QUICK_START.md)
2. Explore the [Architecture Documentation](HOOK_ARCHITECTURE.md)
3. Set up your [Development Environment](DEVELOPMENT.md)
4. Review [Security Best Practices](SECURITY.md)

## Verification

To verify your installation is working:

```bash
# Run the verification script
./scripts/verify-installation.sh

# Or manually check each component
forge --version
go version
node --version
make test
```

If all commands succeed, your installation is complete!
