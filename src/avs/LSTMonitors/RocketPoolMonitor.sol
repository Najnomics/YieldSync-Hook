// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ILSTYieldMonitor.sol";

/**
 * @title RocketPoolMonitor
 * @dev Monitor contract for Rocket Pool rETH yield data
 * @notice Verifies rETH yield data against Rocket Pool's exchange rate
 */
contract RocketPoolMonitor is ILSTYieldMonitor, Ownable, ReentrancyGuard {
    
    /// @notice Rocket Pool rETH contract address
    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    
    /// @notice Rocket Pool Oracle contract address
    address public constant ROCKET_POOL_ORACLE = 0x4c5D8B3A4B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B; // Placeholder
    
    /// @notice Yield data structure
    struct YieldData {
        uint256 exchangeRate;               // rETH/ETH exchange rate
        uint256 lastUpdateTime;             // Last update timestamp
        uint256 annualYieldRate;            // Annual yield rate in basis points
        uint256 totalRETHSupply;            // Total rETH supply
        uint256 totalETHBacking;            // Total ETH backing rETH
    }
    
    /// @notice Yield data storage
    mapping(uint256 => YieldData) public yieldHistory;
    uint256 public yieldDataCounter;
    
    /// @notice Events
    event YieldDataUpdated(
        uint256 indexed dataId,
        uint256 exchangeRate,
        uint256 annualYieldRate,
        uint256 timestamp
    );
    
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    
    /// @notice Modifiers
    modifier onlyValidYieldRate(uint256 yieldRate) {
        require(yieldRate > 0 && yieldRate <= 10000, "RocketPoolMonitor: invalid yield rate"); // 0-100%
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @notice Verify yield proof from Rocket Pool
     * @param yieldRate The yield rate in basis points
     * @param proof The proof data
     * @return isValid Whether the proof is valid
     */
    function verifyYieldProof(
        uint256 yieldRate,
        bytes calldata proof
    ) external view override returns (bool isValid) {
        // Decode proof data
        (uint256 exchangeRate, uint256 totalRETHSupply, uint256 totalETHBacking, uint256 timestamp, bytes32 dataHash) = 
            abi.decode(proof, (uint256, uint256, uint256, uint256, bytes32));
        
        // Validate basic data
        if (exchangeRate == 0 || totalRETHSupply == 0 || totalETHBacking == 0) {
            return false;
        }
        
        // Check timestamp is recent (within 1 hour)
        if (block.timestamp - timestamp > 3600) {
            return false;
        }
        
        // Verify data hash
        bytes32 expectedHash = keccak256(abi.encodePacked(
            exchangeRate,
            totalRETHSupply,
            totalETHBacking,
            timestamp,
            "rocketpool_yield_data"
        ));
        
        if (dataHash != expectedHash) {
            return false;
        }
        
        // Calculate expected yield rate
        uint256 expectedYieldRate = _calculateYieldRate(exchangeRate, totalRETHSupply, totalETHBacking);
        
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
     * @param exchangeRate rETH/ETH exchange rate
     * @param totalRETHSupply Total rETH supply
     * @param totalETHBacking Total ETH backing rETH
     * @param timestamp Update timestamp
     */
    function updateYieldData(
        uint256 exchangeRate,
        uint256 totalRETHSupply,
        uint256 totalETHBacking,
        uint256 timestamp
    ) external onlyOwner nonReentrant {
        require(exchangeRate > 0 && totalRETHSupply > 0 && totalETHBacking > 0, "RocketPoolMonitor: invalid data");
        require(timestamp <= block.timestamp, "RocketPoolMonitor: future timestamp");
        
        // Calculate yield rate
        uint256 annualYieldRate = _calculateYieldRate(exchangeRate, totalRETHSupply, totalETHBacking);
        
        // Store yield data
        uint256 dataId = yieldDataCounter++;
        yieldHistory[dataId] = YieldData({
            exchangeRate: exchangeRate,
            lastUpdateTime: timestamp,
            annualYieldRate: annualYieldRate,
            totalRETHSupply: totalRETHSupply,
            totalETHBacking: totalETHBacking
        });
        
        emit YieldDataUpdated(
            dataId,
            exchangeRate,
            annualYieldRate,
            timestamp
        );
    }
    
    /**
     * @notice Get latest yield data
     * @return data The latest yield data
     */
    function getLatestYieldData() external view returns (YieldData memory data) {
        require(yieldDataCounter > 0, "RocketPoolMonitor: no data available");
        return yieldHistory[yieldDataCounter - 1];
    }
    
    /**
     * @notice Get yield data by ID
     * @param dataId The data ID
     * @return data The yield data
     */
    function getYieldData(uint256 dataId) external view returns (YieldData memory data) {
        require(dataId < yieldDataCounter, "RocketPoolMonitor: invalid data ID");
        return yieldHistory[dataId];
    }
    
    /**
     * @notice Calculate yield rate from exchange rate and backing
     * @param exchangeRate rETH/ETH exchange rate
     * @param totalRETHSupply Total rETH supply
     * @param totalETHBacking Total ETH backing rETH
     * @return yieldRate The annual yield rate in basis points
     */
    function _calculateYieldRate(
        uint256 exchangeRate,
        uint256 totalRETHSupply,
        uint256 totalETHBacking
    ) internal pure returns (uint256 yieldRate) {
        // Calculate the yield based on exchange rate appreciation
        // This is a simplified calculation
        // In production, you'd use historical data to calculate the actual yield
        
        // Base yield rate from Rocket Pool's validator rewards
        uint256 baseRate = 400; // 4% base rate
        
        // Additional yield based on exchange rate vs backing ratio
        uint256 backingRatio = (totalETHBacking * 1e18) / totalRETHSupply;
        uint256 exchangeRateRatio = (exchangeRate * 1e18) / 1e18;
        
        // Calculate bonus based on how much the exchange rate exceeds the backing ratio
        uint256 bonusRate = 0;
        if (exchangeRateRatio > backingRatio) {
            uint256 excess = exchangeRateRatio - backingRatio;
            bonusRate = (excess * 100) / 1e18; // Convert to basis points
        }
        
        yieldRate = baseRate + bonusRate;
        return yieldRate;
    }
    
    /**
     * @notice Get expected yield range for rETH
     * @return minYield Minimum expected yield in basis points
     * @return maxYield Maximum expected yield in basis points
     */
    function getExpectedYieldRange() external pure returns (uint256 minYield, uint256 maxYield) {
        return (300, 600); // 3-6% annual yield range
    }
    
    /**
     * @notice Check if yield data is stale
     * @param dataId The data ID
     * @return isStale Whether the data is stale
     */
    function isYieldDataStale(uint256 dataId) external view returns (bool isStale) {
        require(dataId < yieldDataCounter, "RocketPoolMonitor: invalid data ID");
        
        YieldData memory data = yieldHistory[dataId];
        return block.timestamp - data.lastUpdateTime > 3600; // 1 hour threshold
    }
}
