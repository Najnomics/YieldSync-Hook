package types

import (
	"time"

	"github.com/Layr-Labs/eigensdk-go/crypto/bls"
	sdktypes "github.com/Layr-Labs/eigensdk-go/types"
)

// NodeConfig represents the configuration for the YieldSync operator
type NodeConfig struct {
	// EigenLayer configuration
	EigenLayer struct {
		EcdsaPrivateKeyStorePath string `yaml:"ecdsa_private_key_store_path"`
		BlsPrivateKeyStorePath   string `yaml:"bls_private_key_store_path"`
		OperatorAddress          string `yaml:"operator_address"`
		AVSDirectoryAddress      string `yaml:"avs_directory_address"`
		TokenStrategyAddr        string `yaml:"token_strategy_addr"`
		DelegationManagerAddr    string `yaml:"delegation_manager_addr"`
		StrategyManagerAddr      string `yaml:"strategy_manager_addr"`
		ServiceManagerAddr       string `yaml:"service_manager_addr"`
		TaskManagerAddr          string `yaml:"task_manager_addr"`
		SlashingRegistryCoordinatorAddr string `yaml:"slashing_registry_coordinator_addr"`
		StakeRegistryAddr        string `yaml:"stake_registry_addr"`
		BlsApkRegistryAddr       string `yaml:"bls_apk_registry_addr"`
		IndexRegistryAddr        string `yaml:"index_registry_addr"`
		BlsApkRegistryCoordinatorAddr string `yaml:"bls_apk_registry_coordinator_addr"`
		RegistryCoordinatorAddr  string `yaml:"registry_coordinator_addr"`
		PubkeyCompendiumAddr     string `yaml:"pubkey_compendium_addr"`
		AVSRegistryCoordinatorAddr string `yaml:"avs_registry_coordinator_addr"`
		RewardsCoordinatorAddr   string `yaml:"rewards_coordinator_addr"`
		AllocationManagerAddr    string `yaml:"allocation_manager_addr"`
	} `yaml:"eigenlayer"`

	// Ethereum configuration
	EthRpcUrl     string `yaml:"eth_rpc_url"`
	EthWsUrl      string `yaml:"eth_ws_url"`
	PrivateKey    string `yaml:"private_key"`
	Address       string `yaml:"address"`

	// Chain configuration
	ChainId int `yaml:"chain_id"`

	// Operator configuration
	Operator struct {
		EnableMetrics bool   `yaml:"enable_metrics"`
		MetricsIpPortAddr string `yaml:"metrics_ip_port_addr"`
		EnableNodeApi bool   `yaml:"enable_node_api"`
		NodeApiIpPortAddr string `yaml:"node_api_ip_port_addr"`
		EnableLSTMonitoring bool `yaml:"enable_lst_monitoring"`
		YieldSyncAVSAddr string `yaml:"yieldsync_avs_addr"`
		YieldSyncTaskManagerAddr string `yaml:"yieldsync_task_manager_addr"`
	} `yaml:"operator"`

	// LST monitoring configuration
	LSTMonitoring struct {
		LidoStETHAddress    string `yaml:"lido_steth_address"`
		RocketPoolRETHAddress string `yaml:"rocketpool_reth_address"`
		CoinbaseCBETHAddress string `yaml:"coinbase_cbeth_address"`
		FraxSFRXETHAddress   string `yaml:"frax_sfrxeth_address"`
		MonitoringInterval   time.Duration `yaml:"monitoring_interval"`
		YieldThresholdBPS    uint32 `yaml:"yield_threshold_bps"`
	} `yaml:"lst_monitoring"`

	// Aggregator configuration
	Aggregator struct {
		ServerIpPortAddr string `yaml:"server_ip_port_addr"`
		EnableMetrics    bool   `yaml:"enable_metrics"`
	} `yaml:"aggregator"`

	// Challenger configuration
	Challenger struct {
		EnableMetrics bool   `yaml:"enable_metrics"`
		MetricsIpPortAddr string `yaml:"metrics_ip_port_addr"`
	} `yaml:"challenger"`

	// Logger configuration
	Logger struct {
		Level  string `yaml:"level"`
		Format string `yaml:"format"`
	} `yaml:"logger"`

	// Database configuration
	Database struct {
		Driver string `yaml:"driver"`
		Source string `yaml:"source"`
	} `yaml:"database"`

	// Monitoring configuration
	Monitoring struct {
		EnablePrometheus bool   `yaml:"enable_prometheus"`
		PrometheusPort   int    `yaml:"prometheus_port"`
		EnableGrafana    bool   `yaml:"enable_grafana"`
		GrafanaPort      int    `yaml:"grafana_port"`
	} `yaml:"monitoring"`
}

// AggregatorConfig represents the configuration for the YieldSync aggregator
type AggregatorConfig struct {
	// Environment configuration
	Environment string `yaml:"environment"`

	// Ethereum configuration
	EthRpcUrl     string `yaml:"eth_rpc_url"`
	EthWsUrl      string `yaml:"eth_ws_url"`
	PrivateKey    string `yaml:"private_key"`
	Address       string `yaml:"address"`

	// Chain configuration
	ChainId int `yaml:"chain_id"`

	// Aggregator configuration
	Aggregator struct {
		ServerIpPortAddr string `yaml:"server_ip_port_addr"`
		EnableMetrics    bool   `yaml:"enable_metrics"`
		MetricsIpPortAddr string `yaml:"metrics_ip_port_addr"`
		EnableNodeApi bool   `yaml:"enable_node_api"`
		NodeApiIpPortAddr string `yaml:"node_api_ip_port_addr"`
	} `yaml:"aggregator"`

	// EigenLayer configuration
	EigenLayer struct {
		DelegationManagerAddr string `yaml:"delegation_manager_address"`
		ServiceManagerAddr    string `yaml:"service_manager_address"`
		TaskManagerAddr       string `yaml:"task_manager_address"`
		RegistryCoordinatorAddr string `yaml:"registry_coordinator_address"`
		OperatorStateRetrieverAddr string `yaml:"operator_state_retriever_address"`
		RewardsCoordinatorAddr string `yaml:"rewards_coordinator_address"`
		AllocationManagerAddr string `yaml:"allocation_manager_address"`
	} `yaml:"eigenlayer"`

	// Logger configuration
	Logger struct {
		Level  string `yaml:"level"`
		Format string `yaml:"format"`
	} `yaml:"logger"`

	// Database configuration
	Database struct {
		Driver string `yaml:"driver"`
		Source string `yaml:"source"`
	} `yaml:"database"`

	// Monitoring configuration
	Monitoring struct {
		EnablePrometheus bool   `yaml:"enable_prometheus"`
		PrometheusPort   int    `yaml:"prometheus_port"`
		EnableGrafana    bool   `yaml:"enable_grafana"`
		GrafanaPort      int    `yaml:"grafana_port"`
	} `yaml:"monitoring"`
}

// ChallengerConfig represents the configuration for the YieldSync challenger
type ChallengerConfig struct {
	// Environment configuration
	Environment string `yaml:"environment"`

	// Ethereum configuration
	EthRpcUrl     string `yaml:"eth_rpc_url"`
	EthWsUrl      string `yaml:"eth_ws_url"`
	PrivateKey    string `yaml:"private_key"`
	Address       string `yaml:"address"`

	// Chain configuration
	ChainId int `yaml:"chain_id"`

	// Challenger configuration
	Challenger struct {
		EnableMetrics bool   `yaml:"enable_metrics"`
		MetricsIpPortAddr string `yaml:"metrics_ip_port_addr"`
		EnableNodeApi bool   `yaml:"enable_node_api"`
		NodeApiIpPortAddr string `yaml:"node_api_ip_port_addr"`
	} `yaml:"challenger"`

	// EigenLayer configuration
	EigenLayer struct {
		DelegationManagerAddr string `yaml:"delegation_manager_address"`
		ServiceManagerAddr    string `yaml:"service_manager_address"`
		TaskManagerAddr       string `yaml:"task_manager_address"`
		RegistryCoordinatorAddr string `yaml:"registry_coordinator_address"`
		OperatorStateRetrieverAddr string `yaml:"operator_state_retriever_address"`
		RewardsCoordinatorAddr string `yaml:"rewards_coordinator_address"`
		AllocationManagerAddr string `yaml:"allocation_manager_address"`
	} `yaml:"eigenlayer"`

	// LST monitoring configuration
	LSTMonitoring struct {
		LidoStETHAddress    string `yaml:"lido_steth_address"`
		RocketPoolRETHAddress string `yaml:"rocketpool_reth_address"`
		CoinbaseCBETHAddress string `yaml:"coinbase_cbeth_address"`
		FraxSFRXETHAddress   string `yaml:"frax_sfrxeth_address"`
		MonitoringInterval   time.Duration `yaml:"monitoring_interval"`
		YieldThresholdBPS    uint32 `yaml:"yield_threshold_bps"`
	} `yaml:"lst_monitoring"`

	// Logger configuration
	Logger struct {
		Level  string `yaml:"level"`
		Format string `yaml:"format"`
	} `yaml:"logger"`

	// Database configuration
	Database struct {
		Driver string `yaml:"driver"`
		Source string `yaml:"source"`
	} `yaml:"database"`

	// Monitoring configuration
	Monitoring struct {
		EnablePrometheus bool   `yaml:"enable_prometheus"`
		PrometheusPort   int    `yaml:"prometheus_port"`
		EnableGrafana    bool   `yaml:"enable_grafana"`
		GrafanaPort      int    `yaml:"grafana_port"`
	} `yaml:"monitoring"`
}

// OperatorInfo represents the operator's information
type OperatorInfo struct {
	OperatorAddress string
	OperatorId      sdktypes.OperatorId
	BlsKeypair      *bls.KeyPair
}

// LSTYieldData represents yield data for an LST
type LSTYieldData struct {
	TokenAddress string    `json:"token_address"`
	YieldRate    uint32    `json:"yield_rate"`    // in basis points
	Timestamp    time.Time `json:"timestamp"`
	DataHash     string    `json:"data_hash"`
	Proof        string    `json:"proof"`         // Merkle proof or signature
}

// TaskResponse represents a response to a yield monitoring task
type TaskResponse struct {
	ReferenceTaskIndex uint32           `json:"reference_task_index"`
	YieldRate          uint32           `json:"yield_rate"`
	Timestamp          time.Time        `json:"timestamp"`
	DataHash           string           `json:"data_hash"`
	LSTData            []LSTYieldData   `json:"lst_data"`
}

// Task represents a yield monitoring task
type Task struct {
	LSTToken                string `json:"lst_token"`
	TaskCreatedBlock        uint32 `json:"task_created_block"`
	QuorumNumbers           []byte `json:"quorum_numbers"`
	QuorumThresholdPercentage uint32 `json:"quorum_threshold_percentage"`
}
