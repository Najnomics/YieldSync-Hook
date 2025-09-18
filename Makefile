# YieldSync Hook Makefile
# Following EigenLVR patterns for production deployment

.PHONY: help install build test clean start-anvil deploy setup-dev

# Default target
help: ## Show this help message
	@echo "YieldSync Hook - Available Commands:"
	@echo "====================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Installation and setup
install: ## Install all dependencies
	@echo "Installing dependencies..."
	forge install foundry-rs/forge-std
	forge install OpenZeppelin/openzeppelin-contracts
	forge install Layr-Labs/eigenlayer-middleware
	forge install Uniswap/v4-periphery
	@echo "Dependencies installed!"

# Build commands
build: ## Build all contracts
	@echo "Building contracts..."
	forge build

# Testing
test: ## Run all tests
	@echo "Running tests..."
	forge test -vv

test-gas: ## Run tests with gas reporting
	@echo "Running tests with gas reporting..."
	forge test --gas-report

# Local development
start-anvil: ## Start local Anvil chain
	@echo "Starting Anvil chain..."
	anvil --host 0.0.0.0 --port 8545 --chain-id 31337

# Deployment
deploy-local: ## Deploy to local Anvil
	@echo "Deploying to local Anvil..."
	forge script script/DeployAnvil.s.sol:DeployAnvil --rpc-url http://localhost:8545 --broadcast

deploy-sepolia: ## Deploy to Sepolia testnet
	@echo "Deploying to Sepolia..."
	forge script script/DeployTestnet.s.sol:DeployTestnet --rpc-url sepolia --broadcast --verify

deploy-mainnet: ## Deploy to mainnet
	@echo "Deploying to mainnet..."
	forge script script/DeployMainnet.s.sol:DeployMainnet --rpc-url mainnet --broadcast --verify

# Utility commands
clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	forge clean
	rm -rf out
	rm -rf cache

# Development setup
setup-dev: install build test ## Complete development setup
	@echo "Development environment ready!"

# Status checks
status: ## Check project status
	@echo "YieldSync Hook Project Status:"
	@echo "=============================="
	@echo "Contracts built: $$(if [ -d out ]; then echo "✅ Yes"; else echo "❌ No"; fi)"
	@echo "Dependencies: $$(if [ -d lib ]; then echo "✅ Installed"; else echo "❌ Missing"; fi)"
	@echo "Tests passing: $$(forge test --no-match-test testFuzz 2>/dev/null && echo "✅ Yes" || echo "❌ No")"

# Documentation
docs: ## Generate documentation
	@echo "Generating documentation..."
	forge doc --build

# Linting
lint: ## Run linter
	@echo "Running linter..."
	forge fmt --check

format: ## Format code
	@echo "Formatting code..."
	forge fmt

# Security
slither: ## Run Slither security analysis
	@echo "Running Slither security analysis..."
	slither .

# Coverage
coverage: ## Run test coverage
	@echo "Running test coverage..."
	forge coverage --ir-minimum