# YieldSync Hook AVS

A Hourglass-based Autonomous Verifiable Service (AVS) that provides distributed compute infrastructure for LST yield monitoring and automatic position adjustment operations on Uniswap V4 pools.

## Overview

This AVS serves as a **connector and coordinator** that interfaces with the main YieldSync Hook project. It implements a task-based architecture using the Hourglass framework to provide:

- **Distributed task execution** for LST yield monitoring operations
- **EigenLayer operator management** and staking coordination for yield validators
- **Task validation and fee calculation** for yield monitoring workflows
- **Decentralized consensus** on LST yield data and position adjustments

**Important**: This AVS does **not** contain the yield monitoring business logic itself. It provides the distributed compute layer that interfaces with the main [YieldSync Hook](../src/YieldSyncHook.sol) contract where all yield monitoring and position adjustment logic resides.

## Architecture

This AVS follows the Hourglass DevKit template structure as a **connector system**:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  EigenLayer     │───▶│  L1: Service    │───▶│  L2: Task Hook  │
│  (Yield Ops)    │    │  Manager        │    │  (Connector)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                                       ▼
                                               ┌─────────────────┐
                                               │  Main Project:  │
                                               │  YieldSyncHook  │
                                               │  (Business Logic)│
                                               └─────────────────┘
```

### Directory Structure

```
├── cmd/                          # Performer application (task orchestration)
│   ├── main.go                  # ✅ YieldSync Performer implementation
│   └── main_test.go             # ✅ Comprehensive tests for all task types
├── contracts/                    # AVS connector contracts ONLY
│   ├── src/
│   │   ├── interfaces/          # AVS-specific interfaces
│   │   │   └── IAVSDirectory.sol # ✅ EigenLayer AVS interface
│   │   ├── l1-contracts/        # EigenLayer integration (connectors)
│   │   │   └── YieldSyncServiceManager.sol # ✅ L1 connector only
│   │   └── l2-contracts/        # Task lifecycle management (connectors)
│   │       └── YieldSyncTaskHook.sol # ✅ L2 connector only
│   ├── script/                  # Deployment scripts for connectors
│   │   ├── DeployYieldSyncL1Contracts.s.sol # ✅ Deploy L1 connector
│   │   └── DeployYieldSyncL2Contracts.s.sol # ✅ Deploy L2 connector
│   └── test/                    # Connector contract tests
│       ├── YieldSyncServiceManager.t.sol # ✅ L1 connector tests
│       └── YieldSyncTaskHook.t.sol       # ✅ L2 connector tests
├── .devkit/                     # DevKit integration
├── .hourglass/                  # Hourglass framework configuration
├── go.mod                       # ✅ Go dependencies (Hourglass/Ponos)
├── go.sum                       # ✅ Dependency checksums
└── README.md                    # This file
```

**❌ Business Logic NOT in AVS:**
- Main YieldSync Hook logic → `../src/YieldSyncHook.sol`
- LST yield calculations → `../src/libraries/YieldCalculations.sol`
- Position adjustment logic → `../src/libraries/PositionAdjustment.sol`
- LST protocol integrations → `../src/monitors/LSTMonitors/`

### Component Responsibilities

**✅ AVS Contracts (Connectors Only):**
- **L1 ServiceManager** (`YieldSyncServiceManager.sol`):
  - EigenLayer operator registration and staking coordination for yield monitoring
  - Extends `TaskAVSRegistrarBase` for EigenLayer integration
  - References main YieldSync hook address (does not contain yield logic)
  - Supports LST token management (stETH, rETH, cbETH, sfrxETH)
  
- **L2 TaskHook** (`YieldSyncTaskHook.sol`):
  - Implements `IAVSTaskHook` for Hourglass task lifecycle management
  - Validates YieldSync task parameters and calculates fees
  - Interfaces with main hook contract (does not replace it)

**✅ Go Performer (`cmd/main.go`):**
- **Task Orchestration**: Coordinates distributed execution of YieldSync tasks
- **Payload Parsing**: Handles 5 task types (yield monitoring, position adjustment, risk assessment, rebalancing, LST validation)
- **Result Aggregation**: Aggregates responses from operators for consensus
- **Hourglass Integration**: Implements `ValidateTask` and `HandleTask` interfaces

**❌ Main Project (Business Logic - deployed separately):**
- **YieldSyncHook** (`../src/YieldSyncHook.sol`): All yield monitoring and position adjustment logic
- **LST Monitors** (`../src/monitors/LSTMonitors/`): LST protocol integration logic
- **Yield Libraries** (`../src/libraries/YieldCalculations.sol`): Yield calculation logic

## Quick Start

### Prerequisites

- [Docker (latest)](https://docs.docker.com/engine/install/)
- [Foundry (latest)](https://book.getfoundry.sh/getting-started/installation)
- [Go (v1.23.6)](https://go.dev/doc/install)
- [DevKit CLI](https://github.com/Layr-Labs/devkit-cli)

### Build

```bash
# Build the performer binary
make build

# Build contracts
make build-contracts

# Build everything
make
```

### Development with DevKit

```bash
# Build AVS and contracts
devkit avs build --image yieldsync-hook

# Start local development network
devkit avs devnet start

# Run the performer
devkit avs run

# Simulate tasks
devkit avs call --task-type yield_monitoring
```

### Testing

```bash
# Run all tests
make test

# Run Go tests only
make test-go

# Run Forge tests only
make test-forge
```

## Task Types

The YieldSync Performer coordinates distributed execution of five main task types:

### 1. Yield Monitoring Tasks
- **Coordinate** LST yield monitoring across multiple operators
- **Validate** yield data from stETH, rETH, cbETH, sfrxETH protocols
- **Aggregate** yield monitoring results from distributed operators

### 2. Position Adjustment Tasks  
- **Orchestrate** LP position adjustment calculations across the network
- **Validate** position adjustment parameters and tick ranges
- **Coordinate** position updates with the main YieldSync Hook

### 3. Risk Assessment Tasks
- **Distribute** LST risk assessment work across operators
- **Validate** validator performance and slashing risk data
- **Aggregate** risk assessment results for consensus

### 4. Rebalancing Tasks
- **Coordinate** portfolio rebalancing across multiple LST positions
- **Validate** rebalancing parameters and target allocations
- **Orchestrate** rebalancing execution through the main hook contract

### 5. LST Validation Tasks
- **Distribute** LST contract validation across operators
- **Validate** LST authenticity and validator health
- **Aggregate** validation results for LST support decisions

**Note**: The actual yield monitoring logic (yield calculations, position adjustments, etc.) is executed by the main [YieldSyncHook](../src/YieldSyncHook.sol) contract. The AVS provides distributed consensus and coordination.

## Configuration

Configuration is managed through the Hourglass framework:

- **`.hourglass/config/`** - Framework configuration
- **`.hourglass/context/`** - Environment-specific settings
- **`.devkit/`** - Development tooling configuration

## Smart Contracts

### AVS Connector Contracts

#### L1 Contracts (Ethereum Mainnet)
- **YieldSyncServiceManager.sol** - EigenLayer connector only
  - ✅ Extends `TaskAVSRegistrarBase` for DevKit compliance
  - ✅ Handles operator registration with minimum 10 ETH stake
  - ✅ References YieldSync hook address for coordination
  - ✅ Supports LST token management (stETH, rETH, cbETH, sfrxETH)
  - ❌ **No yield monitoring business logic** - pure EigenLayer integration

#### L2 Contracts (Optimism/Arbitrum/etc.)
- **YieldSyncTaskHook.sol** - Task system connector only
  - ✅ Implements `IAVSTaskHook` for Hourglass integration
  - ✅ Validates 5 YieldSync task types with proper fee structure
  - ✅ Calculates task fees (0.001-0.01 ETH based on complexity)
  - ❌ **No yield monitoring business logic** - interfaces with main hook

### Main Project Contracts (deployed separately)

#### Core Business Logic (in main project)
- **[YieldSyncHook.sol](../src/YieldSyncHook.sol)** - All yield monitoring functionality
  - ✅ Uniswap V4 hook with complete yield monitoring implementation
  - ✅ LST yield tracking, position adjustment, IL prevention
  - ✅ **All business logic here** - AVS provides distributed coordination

#### Supporting Infrastructure (in main project)
- **[YieldCalculations.sol](../src/libraries/YieldCalculations.sol)** - Yield math libraries
- **[PositionAdjustment.sol](../src/libraries/PositionAdjustment.sol)** - Position utilities
- **[LSTMonitors/](../src/monitors/LSTMonitors/)** - LST protocol integrations

## Deployment

### Prerequisites
1. **Deploy main YieldSync Hook** first in your main project
2. **Note the deployed hook address** - you'll need it for AVS deployment

### AVS Deployment
Deployment is handled through DevKit scripts:

```bash
# 1. Deploy L1 AVS contracts (EigenLayer integration)
forge script contracts/script/DeployYieldSyncL1Contracts.s.sol:DeployYieldSyncL1Contracts

# 2. Deploy L2 AVS contracts (requires main hook address)
# Edit .hourglass/context/{environment}.json to include:
# {
#   "l2": {
#     "yieldSyncHook": "0x..." // Your deployed main hook address
#   },
#   "l1": {
#     "serviceManager": "0x..." // From L1 deployment
#   }
# }

forge script contracts/script/DeployYieldSyncL2Contracts.s.sol:DeployYieldSyncL2Contracts
```

### Deployment Order
1. **Main Project**: Deploy `YieldSyncHook.sol` from main project
2. **AVS L1**: Deploy `YieldSyncServiceManager` (EigenLayer integration)  
3. **AVS L2**: Deploy `YieldSyncTaskHook` (connects to main hook)

## API

The performer exposes a gRPC server on port 8080 implementing the Hourglass Performer interface:

- `ValidateTask(TaskRequest) -> error` - Validates YieldSync task parameters
- `HandleTask(TaskRequest) -> TaskResponse` - Coordinates task execution with main hook

### Task Payload Structure

Tasks are JSON payloads with the following structure:
```json
{
  "type": "YIELD_MONITORING|POSITION_ADJUSTMENT|RISK_ASSESSMENT|REBALANCING|LST_VALIDATION", 
  "parameters": {
    "poolId": "0x...",
    "lstToken": "0x...",
    "threshold": 0.5,
    // ... task-specific parameters
  },
  "lstData": [...],
  "position": {...}
}
```

The performer validates these parameters and coordinates execution with the main YieldSync Hook contract.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.