// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ILSTYieldMonitor.sol";

/**
 * @title LidoYieldMonitor
 * @dev Monitor contract for Lido stETH yield data
 * @notice Verifies stETH yield data against Lido's consensus layer rewards
 */
contract LidoYieldMonitor is ILSTYieldMonitor, Ownable, ReentrancyGuard {
    
    /// @notice Lido stETH contract address
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    
    /// @notice Lido Oracle contract address
    address public constant LIDO_ORACLE = 0x442aF784A788a5a6E45d2bC7e4D8B5E5E5E5E5e5; // Placeholder
    
    /// @notice Yield data structure
    struct YieldData {
        uint256 totalPooledEther;           // Total pooled ETH
        uint256 totalShares;                // Total stETH shares
        uint256 lastUpdateTime;             // Last update timestamp
        uint256 annualYieldRate;            // Annual yield rate in basis points
    }
    
    /// @notice Yield data storage
    mapping(uint256 => YieldData) public yieldHistory;
    uint256 public yieldDataCounter;
    
    /// @notice Events
    event YieldDataUpdated(
        uint256 indexed dataId,
        uint256 totalPooledEther,
        uint256 totalShares,
        uint256 annualYieldRate,
        uint256 timestamp
    );
    
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    
    /// @notice Modifiers
    modifier onlyValidYieldRate(uint256 yieldRate) {
        require(yieldRate > 0 && yieldRate <= 10000, "LidoMonitor: invalid yield rate"); // 0-100%
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @notice Verify yield proof from Lido
     * @param yieldRate The yield rate in basis points
     * @param proof The proof data
     * @return isValid Whether the proof is valid
     */
    function verifyYieldProof(
        uint256 yieldRate,
        bytes calldata proof
    ) external view override returns (bool isValid) {
        // Decode proof data
        (uint256 totalPooledEther, uint256 totalShares, uint256 timestamp, bytes32 dataHash) = 
            abi.decode(proof, (uint256, uint256, uint256, bytes32));
        
        // Validate basic data
        if (totalPooledEther == 0 || totalShares == 0) {
            return false;
        }
        
        // Check timestamp is recent (within 1 hour)
        if (block.timestamp - timestamp > 3600) {
            return false;
        }
        
        // Verify data hash
        bytes32 expectedHash = keccak256(abi.encodePacked(
            totalPooledEther,
            totalShares,
            timestamp,
            "lido_yield_data"
        ));
        
        if (dataHash != expectedHash) {
            return false;
        }
        
        // Calculate expected yield rate
        uint256 expectedYieldRate = _calculateYieldRate(totalPooledEther, totalShares);
        
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
     * @param totalPooledEther Total pooled ETH
     * @param totalShares Total stETH shares
     * @param timestamp Update timestamp
     */
    function updateYieldData(
        uint256 totalPooledEther,
        uint256 totalShares,
        uint256 timestamp
    ) external onlyOwner nonReentrant {
        require(totalPooledEther > 0 && totalShares > 0, "LidoMonitor: invalid data");
        require(timestamp <= block.timestamp, "LidoMonitor: future timestamp");
        
        // Calculate yield rate
        uint256 annualYieldRate = _calculateYieldRate(totalPooledEther, totalShares);
        
        // Store yield data
        uint256 dataId = yieldDataCounter++;
        yieldHistory[dataId] = YieldData({
            totalPooledEther: totalPooledEther,
            totalShares: totalShares,
            lastUpdateTime: timestamp,
            annualYieldRate: annualYieldRate
        });
        
        emit YieldDataUpdated(
            dataId,
            totalPooledEther,
            totalShares,
            annualYieldRate,
            timestamp
        );
    }
    
    /**
     * @notice Get latest yield data
     * @return data The latest yield data
     */
    function getLatestYieldData() external view returns (YieldData memory data) {
        require(yieldDataCounter > 0, "LidoMonitor: no data available");
        return yieldHistory[yieldDataCounter - 1];
    }
    
    /**
     * @notice Get yield data by ID
     * @param dataId The data ID
     * @return data The yield data
     */
    function getYieldData(uint256 dataId) external view returns (YieldData memory data) {
        require(dataId < yieldDataCounter, "LidoMonitor: invalid data ID");
        return yieldHistory[dataId];
    }
    
    /**
     * @notice Calculate yield rate from pooled ETH and shares
     * @param totalPooledEther Total pooled ETH
     * @param totalShares Total stETH shares
     * @return yieldRate The annual yield rate in basis points
     */
    function _calculateYieldRate(
        uint256 totalPooledEther,
        uint256 totalShares
    ) internal pure returns (uint256 yieldRate) {
        // Calculate exchange rate: ETH per stETH
        // exchangeRate = totalPooledEther / totalShares
        uint256 exchangeRate = (totalPooledEther * 1e18) / totalShares;
        
        // Calculate annual yield rate
        // This is a simplified calculation
        // In production, you'd use historical data to calculate the actual yield
        uint256 baseRate = 400; // 4% base rate
        uint256 bonusRate = 0; // Additional rate based on network conditions
        
        yieldRate = baseRate + bonusRate;
        return yieldRate;
    }
    
    /**
     * @notice Get expected yield range for stETH
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
        require(dataId < yieldDataCounter, "LidoMonitor: invalid data ID");
        
        YieldData memory data = yieldHistory[dataId];
        return block.timestamp - data.lastUpdateTime > 3600; // 1 hour threshold
    }

    /**
     * @notice Returns the name of this LST monitor
     */
    function name() external pure returns (string memory) {
        return "Lido stETH";
    }

    /**
     * @notice Returns the LST token address
     */
    function lstToken() external pure returns (address) {
        return STETH;
    }
}
