package core

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/YieldSync/yieldsync-operator/types"
	sdklogging "github.com/Layr-Labs/eigensdk-go/logging"
)

// LSTMonitor monitors LST yield rates
type LSTMonitor struct {
	name        string
	tokenAddress common.Address
	ethClient   *ethclient.Client
	logger      sdklogging.Logger
	
	// Yield data tracking
	lastYieldData *types.LSTYieldData
	yieldHistory  []types.LSTYieldData
}

// NewLSTMonitor creates a new LST monitor
func NewLSTMonitor(name, tokenAddress string, logger sdklogging.Logger) *LSTMonitor {
	return &LSTMonitor{
		name:        name,
		tokenAddress: common.HexToAddress(tokenAddress),
		logger:      logger,
		yieldHistory: make([]types.LSTYieldData, 0),
	}
}

// Start starts the LST monitor
func (lm *LSTMonitor) Start(ctx context.Context, interval time.Duration) error {
	lm.logger.Info("Starting LST monitor", "name", lm.name, "address", lm.tokenAddress.Hex())
	
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	
	for {
		select {
		case <-ctx.Done():
			lm.logger.Info("LST monitor stopped", "name", lm.name)
			return ctx.Err()
		case <-ticker.C:
			if err := lm.updateYieldData(); err != nil {
				lm.logger.Error("Error updating yield data", "name", lm.name, "error", err)
			}
		}
	}
}

// updateYieldData updates the yield data for the LST
func (lm *LSTMonitor) updateYieldData() error {
	yieldData, err := lm.fetchYieldData()
	if err != nil {
		return fmt.Errorf("failed to fetch yield data: %w", err)
	}
	
	lm.lastYieldData = yieldData
	lm.yieldHistory = append(lm.yieldHistory, *yieldData)
	
	// Keep only last 100 entries
	if len(lm.yieldHistory) > 100 {
		lm.yieldHistory = lm.yieldHistory[1:]
	}
	
	lm.logger.Info("Updated yield data", 
		"name", lm.name,
		"yieldRate", yieldData.YieldRate,
		"timestamp", yieldData.Timestamp,
	)
	
	return nil
}

// fetchYieldData fetches the current yield data for the LST
func (lm *LSTMonitor) fetchYieldData() (*types.LSTYieldData, error) {
	var yieldRate uint32
	var err error
	
	switch lm.name {
	case "stETH":
		yieldRate, err = lm.getStETHYieldRate()
	case "rETH":
		yieldRate, err = lm.getRETHYieldRate()
	case "cbETH":
		yieldRate, err = lm.getCBETHYieldRate()
	case "sfrxETH":
		yieldRate, err = lm.getSFRXETHYieldRate()
	default:
		return nil, fmt.Errorf("unsupported LST: %s", lm.name)
	}
	
	if err != nil {
		return nil, fmt.Errorf("failed to get yield rate for %s: %w", lm.name, err)
	}
	
	// Create data hash
	dataHash := lm.createDataHash(yieldRate)
	
	return &types.LSTYieldData{
		TokenAddress: lm.tokenAddress.Hex(),
		YieldRate:    yieldRate,
		Timestamp:    time.Now(),
		DataHash:     dataHash,
		Proof:        "", // This would be a Merkle proof or signature
	}, nil
}

// getStETHYieldRate gets the yield rate for stETH
func (lm *LSTMonitor) getStETHYieldRate() (uint32, error) {
	// This would call the Lido contract to get the current yield rate
	// For now, return a mock value
	return 350, nil // 3.5% annual yield
}

// getRETHYieldRate gets the yield rate for rETH
func (lm *LSTMonitor) getRETHYieldRate() (uint32, error) {
	// This would call the Rocket Pool contract to get the current yield rate
	// For now, return a mock value
	return 320, nil // 3.2% annual yield
}

// getCBETHYieldRate gets the yield rate for cbETH
func (lm *LSTMonitor) getCBETHYieldRate() (uint32, error) {
	// This would call the Coinbase contract to get the current yield rate
	// For now, return a mock value
	return 380, nil // 3.8% annual yield
}

// getSFRXETHYieldRate gets the yield rate for sfrxETH
func (lm *LSTMonitor) getSFRXETHYieldRate() (uint32, error) {
	// This would call the Frax contract to get the current yield rate
	// For now, return a mock value
	return 340, nil // 3.4% annual yield
}

// createDataHash creates a hash of the yield data
func (lm *LSTMonitor) createDataHash(yieldRate uint32) string {
	data := fmt.Sprintf("%s:%d:%d", lm.tokenAddress.Hex(), yieldRate, time.Now().Unix())
	hash := sha256.Sum256([]byte(data))
	return hex.EncodeToString(hash[:])
}

// GetLatestYieldData returns the latest yield data
func (lm *LSTMonitor) GetLatestYieldData() (*types.LSTYieldData, error) {
	if lm.lastYieldData == nil {
		return nil, fmt.Errorf("no yield data available")
	}
	return lm.lastYieldData, nil
}

// GetYieldHistory returns the yield history
func (lm *LSTMonitor) GetYieldHistory() []types.LSTYieldData {
	return lm.yieldHistory
}

// GetName returns the name of the LST
func (lm *LSTMonitor) GetName() string {
	return lm.name
}

// GetTokenAddress returns the token address
func (lm *LSTMonitor) GetTokenAddress() common.Address {
	return lm.tokenAddress
}
