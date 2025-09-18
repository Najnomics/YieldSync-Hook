// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ILSTYieldMonitor.sol";

/**
 * @title CoinbaseMonitor
 * @dev Monitor contract for Coinbase cbETH yield data
 * @notice Verifies cbETH yield data against Coinbase's institutional staking
 */
contract CoinbaseMonitor is ILSTYieldMonitor, Ownable, ReentrancyGuard {
    
    /// @notice Coinbase cbETH contract address
    address public constant CBETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    
    /// @notice Coinbase Oracle contract address
    address public constant COINBASE_ORACLE = 0x5e5E5e5e5E5e5E5E5e5E5E5e5e5E5E5E5e5E5E5e; // Placeholder
    
    /// @notice Yield data structure
    struct YieldData {
        uint256 exchangeRate;               // cbETH/ETH exchange rate
        uint256 lastUpdateTime;             // Last update timestamp
        uint256 annualYieldRate;            // Annual yield rate in basis points
        uint256 totalCBETHSupply;           // Total cbETH supply
        uint256 totalETHBacking;            // Total ETH backing cbETH
        uint256 validatorCount;             // Number of validators
    }
    
    /// @notice Yield data storage
    mapping(uint256 => YieldData) public yieldHistory;
    uint256 public yieldDataCounter;
    
    /// @notice Events
    event YieldDataUpdated(
        uint256 indexed dataId,
        uint256 exchangeRate,
        uint256 annualYieldRate,
        uint256 validatorCount,
        uint256 timestamp
    );
    
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    
    /// @notice Modifiers
    modifier onlyValidYieldRate(uint256 yieldRate) {
        require(yieldRate > 0 && yieldRate <= 10000, "CoinbaseMonitor: invalid yield rate"); // 0-100%
        _;
    }
    
    constructor() Ownable() {}
    
    /**
     * @notice Verify yield proof from Coinbase
     * @param yieldRate The yield rate in basis points
     * @param proof The proof data
     * @return isValid Whether the proof is valid
     */
    function verifyYieldProof(
        uint256 yieldRate,
        bytes calldata proof
    ) external view override returns (bool isValid) {
        // Decode proof data
        (uint256 exchangeRate, uint256 totalCBETHSupply, uint256 totalETHBacking, uint256 validatorCount, uint256 timestamp, bytes32 dataHash) = 
            abi.decode(proof, (uint256, uint256, uint256, uint256, uint256, bytes32));
        
        // Validate basic data
        if (exchangeRate == 0 || totalCBETHSupply == 0 || totalETHBacking == 0) {
            return false;
        }
        
        // Check timestamp is recent (within 1 hour)
        if (block.timestamp - timestamp > 3600) {
            return false;
        }
        
        // Verify data hash
        bytes32 expectedHash = keccak256(abi.encodePacked(
            exchangeRate,
            totalCBETHSupply,
            totalETHBacking,
            validatorCount,
            timestamp,
            "coinbase_yield_data"
        ));
        
        if (dataHash != expectedHash) {
            return false;
        }
        
        // Calculate expected yield rate
        uint256 expectedYieldRate = _calculateYieldRate(exchangeRate, totalCBETHSupply, totalETHBacking, validatorCount);
        
        // Check if provided yield rate is within acceptable range
        uint256 deviation = yieldRate > expectedYieldRate ? 
            yieldRate - expectedYieldRate : 
            expectedYieldRate - yieldRate;
        
        // Allow 5% deviation
        uint256 maxDeviation = expectedYieldRate / 20; // 5%
        
        return deviation <= maxDeviation;
    }
    
    /**
     * @notice Update yield data (called by oracle)
     * @param exchangeRate cbETH/ETH exchange rate
     * @param totalCBETHSupply Total cbETH supply
     * @param totalETHBacking Total ETH backing cbETH
     * @param validatorCount Number of validators
     * @param timestamp Update timestamp
     */
    function updateYieldData(
        uint256 exchangeRate,
        uint256 totalCBETHSupply,
        uint256 totalETHBacking,
        uint256 validatorCount,
        uint256 timestamp
    ) external onlyOwner nonReentrant {
        require(exchangeRate > 0 && totalCBETHSupply > 0 && totalETHBacking > 0, "CoinbaseMonitor: invalid data");
        require(timestamp <= block.timestamp, "CoinbaseMonitor: future timestamp");
        
        // Calculate yield rate
        uint256 annualYieldRate = _calculateYieldRate(exchangeRate, totalCBETHSupply, totalETHBacking, validatorCount);
        
        // Store yield data
        uint256 dataId = yieldDataCounter++;
        yieldHistory[dataId] = YieldData({
            exchangeRate: exchangeRate,
            lastUpdateTime: timestamp,
            annualYieldRate: annualYieldRate,
            totalCBETHSupply: totalCBETHSupply,
            totalETHBacking: totalETHBacking,
            validatorCount: validatorCount
        });
        
        emit YieldDataUpdated(
            dataId,
            exchangeRate,
            annualYieldRate,
            validatorCount,
            timestamp
        );
    }
    
    /**
     * @notice Get latest yield data
     * @return data The latest yield data
     */
    function getLatestYieldData() external view returns (YieldData memory data) {
        require(yieldDataCounter > 0, "CoinbaseMonitor: no data available");
        return yieldHistory[yieldDataCounter - 1];
    }
    
    /**
     * @notice Get yield data by ID
     * @param dataId The data ID
     * @return data The yield data
     */
    function getYieldData(uint256 dataId) external view returns (YieldData memory data) {
        require(dataId < yieldDataCounter, "CoinbaseMonitor: invalid data ID");
        return yieldHistory[dataId];
    }
    
    /**
     * @notice Calculate yield rate from exchange rate and backing
     * @param exchangeRate cbETH/ETH exchange rate
     * @param totalCBETHSupply Total cbETH supply
     * @param totalETHBacking Total ETH backing cbETH
     * @param validatorCount Number of validators
     * @return yieldRate The annual yield rate in basis points
     */
    function _calculateYieldRate(
        uint256 exchangeRate,
        uint256 totalCBETHSupply,
        uint256 totalETHBacking,
        uint256 validatorCount
    ) internal pure returns (uint256 yieldRate) {
        // Calculate the yield based on exchange rate appreciation
        // This is a simplified calculation
        // In production, you'd use historical data to calculate the actual yield
        
        // Base yield rate from Coinbase's institutional staking
        uint256 baseRate = 350; // 3.5% base rate (slightly lower than decentralized)
        
        // Additional yield based on exchange rate vs backing ratio
        uint256 backingRatio = (totalETHBacking * 1e18) / totalCBETHSupply;
        uint256 exchangeRateRatio = (exchangeRate * 1e18) / 1e18;
        
        // Calculate bonus based on how much the exchange rate exceeds the backing ratio
        uint256 bonusRate = 0;
        if (exchangeRateRatio > backingRatio) {
            uint256 excess = exchangeRateRatio - backingRatio;
            bonusRate = (excess * 100) / 1e18; // Convert to basis points
        }
        
        // Validator efficiency bonus
        uint256 validatorBonus = 0;
        if (validatorCount > 1000) { // More validators = better efficiency
            validatorBonus = 50; // 0.5% bonus
        }
        
        yieldRate = baseRate + bonusRate + validatorBonus;
        return yieldRate;
    }
    
    /**
     * @notice Get expected yield range for cbETH
     * @return minYield Minimum expected yield in basis points
     * @return maxYield Maximum expected yield in basis points
     */
    function getExpectedYieldRange() external pure returns (uint256 minYield, uint256 maxYield) {
        return (250, 550); // 2.5-5.5% annual yield range (slightly lower than decentralized)
    }
    
    /**
     * @notice Check if yield data is stale
     * @param dataId The data ID
     * @return isStale Whether the data is stale
     */
    function isYieldDataStale(uint256 dataId) external view returns (bool isStale) {
        require(dataId < yieldDataCounter, "CoinbaseMonitor: invalid data ID");
        
        YieldData memory data = yieldHistory[dataId];
        return block.timestamp - data.lastUpdateTime > 3600; // 1 hour threshold
    }

    /**
     * @notice Returns the name of this LST monitor
     */
    function name() external pure returns (string memory) {
        return "Coinbase cbETH";
    }

    /**
     * @notice Returns the LST token address
     */
    function lstToken() external pure returns (address) {
        return CBETH;
    }
}
