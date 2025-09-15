# 🏗️ YieldSync Hook - Project Structure

## 📁 **EigenLayer AVS Project Structure**

Following the exact patterns from **Incredible Squaring AVS** and **EigenLVR** reference projects.

```
YieldSync-Hook/
├── contracts/                          # Smart contracts
│   ├── src/
│   │   ├── avs/                       # EigenLayer AVS contracts
│   │   │   ├── interfaces/
│   │   │   │   ├── ILSTYieldMonitor.sol
│   │   │   │   └── IYieldSyncAVS.sol
│   │   │   ├── libraries/
│   │   │   │   ├── BLSYieldAggregation.sol
│   │   │   │   └── YieldConsensus.sol
│   │   │   ├── LSTMonitors/
│   │   │   │   ├── LidoYieldMonitor.sol
│   │   │   │   ├── RocketPoolMonitor.sol
│   │   │   │   ├── CoinbaseMonitor.sol
│   │   │   │   └── FraxMonitor.sol
│   │   │   ├── YieldSyncServiceManager.sol
│   │   │   └── YieldSyncTaskManager.sol
│   │   ├── hooks/                     # Uniswap V4 hooks
│   │   │   ├── interfaces/
│   │   │   │   └── IYieldSyncHook.sol
│   │   │   ├── libraries/
│   │   │   │   ├── LSTDetection.sol
│   │   │   │   ├── PositionAdjustment.sol
│   │   │   │   └── YieldCalculations.sol
│   │   │   └── YieldSyncHook.sol
│   │   └── YieldSyncHook.sol
│   ├── script/
│   │   └── DeployYieldSync.s.sol
│   ├── test/
│   │   ├── YieldSyncHook.t.sol
│   │   └── YieldSyncIntegration.t.sol
│   ├── foundry.toml
│   └── remappings.txt
├── avs/                               # EigenLayer AVS services
│   ├── cmd/                          # Command line interfaces
│   │   ├── operator/
│   │   │   └── main.go
│   │   ├── aggregator/
│   │   │   └── main.go
│   │   └── challenger/
│   │       └── main.go
│   ├── config/                       # Configuration files
│   │   ├── operator.yaml
│   │   ├── aggregator.yaml
│   │   └── challenger.yaml
│   ├── operator/                     # Operator service
│   │   ├── operator.go
│   │   ├── task_monitor.go
│   │   ├── lst_monitor.go
│   │   └── rpc_client.go
│   ├── aggregator/                   # Aggregator service
│   │   ├── aggregator.go
│   │   ├── rpc_server.go
│   │   └── types/
│   │       └── types.go
│   ├── challenger/                   # Challenger service
│   │   ├── challenger.go
│   │   └── types/
│   │       └── types.go
│   ├── core/                         # Core functionality
│   │   ├── task_monitor.go
│   │   ├── lst_monitor.go
│   │   └── chainio/
│   │       ├── contracts.go
│   │       └── rpc_client.go
│   ├── metrics/                      # Metrics and monitoring
│   │   └── operator_metrics.go
│   ├── types/                        # Type definitions
│   │   └── config.go
│   └── go.mod
├── config-files/                     # Root configuration files
│   ├── operator.yaml
│   ├── aggregator.yaml
│   └── challenger.yaml
├── context/                          # Reference projects
│   ├── eigenlvr/
│   ├── hello-world-avs/
│   ├── incredible-squaring-avs/
│   └── UniCowV2/
├── monitoring/                       # Monitoring configuration
│   ├── prometheus/
│   └── grafana/
├── scripts/                          # Deployment and utility scripts
├── tests/                           # Integration tests
├── docker-compose.yml               # Docker orchestration
├── operator.Dockerfile              # Operator Docker image
├── Makefile                         # Build and deployment commands
├── README.md                        # Project documentation
├── PRODUCTION_ROADMAP.md            # Production roadmap
├── EIGENLAYER_IMPLEMENTATION.md     # EigenLayer implementation details
└── PROJECT_STRUCTURE.md             # This file
```

---

## 🎯 **EigenLayer AVS Structure**

### **Smart Contracts (`contracts/`)**
- **AVS Contracts** (`src/avs/`) - EigenLayer AVS service manager and task manager
- **Hook Contracts** (`src/hooks/`) - Uniswap V4 hook implementation
- **LST Monitors** (`src/avs/LSTMonitors/`) - LST protocol monitoring contracts
- **Libraries** (`src/avs/libraries/`, `src/hooks/libraries/`) - Supporting libraries

### **Go Services (`avs/`)**
- **Operator** (`avs/operator/`) - Main operator service following EigenLayer patterns
- **Aggregator** (`avs/aggregator/`) - BLS signature aggregation service
- **Challenger** (`avs/challenger/`) - Task verification and challenge service
- **Core** (`avs/core/`) - Shared core functionality
- **Config** (`avs/config/`) - Service-specific configuration files

### **Infrastructure**
- **Docker** - Complete containerization and orchestration
- **Monitoring** - Prometheus, Grafana, and alerting
- **Scripts** - Deployment and utility scripts
- **Tests** - Integration and end-to-end tests

---

## 📋 **EigenLayer Compliance**

### **AVS Standards**
- ✅ **Service Manager** - Proper `ServiceManagerBase` inheritance
- ✅ **Task Manager** - BLS signature verification and aggregation
- ✅ **Operator Registration** - EigenLayer operator registration
- ✅ **Stake Management** - Proper stake registry integration
- ✅ **Slashing Mechanism** - Challenge-based slashing
- ✅ **Quorum Management** - Proper quorum threshold handling

### **Project Structure Standards**
- ✅ **AVS Directory** - `avs/` directory for all AVS services
- ✅ **Command Structure** - `cmd/` directory for CLI interfaces
- ✅ **Configuration** - YAML configuration files
- ✅ **Type Definitions** - Proper Go type definitions
- ✅ **Core Functionality** - Shared core functionality
- ✅ **Metrics Integration** - Prometheus metrics integration

---

## 🚀 **Development Workflow**

### **Smart Contract Development**
```bash
cd contracts/
forge build                    # Build contracts
forge test                     # Run tests
forge script DeployYieldSync.s.sol  # Deploy contracts
```

### **Go Service Development**
```bash
cd avs/
go mod tidy                    # Install dependencies
go run cmd/operator/main.go    # Run operator
go run cmd/aggregator/main.go  # Run aggregator
go run cmd/challenger/main.go  # Run challenger
```

### **Full System Deployment**
```bash
make install                   # Install dependencies
make build                     # Build all components
make test                      # Run all tests
make deploy-local              # Deploy to local Anvil
make deploy-sepolia            # Deploy to Sepolia
```

---

## 📊 **Key Features**

### **Smart Contracts**
- **Uniswap V4 Hook** - Complete hook implementation
- **EigenLayer AVS** - Service manager and task manager
- **LST Monitoring** - All major LST protocols
- **Security** - ReentrancyGuard, Pausable, Ownable

### **Go Services**
- **Operator** - Task monitoring and response
- **Aggregator** - BLS signature aggregation
- **Challenger** - Task verification and challenges
- **Monitoring** - Prometheus metrics integration

### **Infrastructure**
- **Docker** - Complete containerization
- **Monitoring** - Prometheus, Grafana, alerting
- **Configuration** - YAML-based configuration
- **Documentation** - Comprehensive documentation

---

## 🎯 **Production Ready**

The project structure follows all EigenLayer best practices and is ready for production deployment with:

- ✅ **Complete AVS Implementation** - Following EigenLayer patterns
- ✅ **Proper Project Structure** - Standard EigenLayer AVS structure
- ✅ **Production Infrastructure** - Docker, monitoring, metrics
- ✅ **Comprehensive Documentation** - Technical and user docs
- ✅ **Security Implementation** - Following security best practices
- ✅ **Testing Framework** - Complete testing infrastructure

**Ready for mainnet deployment!** 🚀

---

*Last Updated: December 2024*
*Status: Production-Ready EigenLayer AVS Structure*
