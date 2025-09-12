// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BLSYieldAggregation.sol";

/**
 * @title YieldConsensus
 * @dev Library for managing yield data consensus
 */
library YieldConsensus {
    /// @notice Consensus data structure
    struct ConsensusData {
        address lstToken;                   // LST token address
        uint256 totalSubmissions;           // Total number of submissions
        uint256 consensusYieldRate;         // Consensus yield rate
        uint256 lastUpdateTime;             // Last update timestamp
        mapping(address => bool) hasSubmitted; // Track which operators have submitted
        mapping(address => uint256) operatorSubmissions; // Track operator submission counts
    }

    /// @notice Consensus parameters
    struct ConsensusParams {
        uint256 minSubmissions;             // Minimum submissions required
        uint256 consensusThreshold;         // Consensus threshold in basis points
        uint256 maxDeviation;               // Maximum deviation allowed
        uint256 stalenessThreshold;         // Staleness threshold in seconds
    }

    /// @notice Add a yield submission to consensus data
    /// @param consensus The consensus data storage
    /// @param submission The yield submission
    /// @param signature The BLS signature
    function addSubmission(
        ConsensusData storage consensus,
        BLSYieldAggregation.YieldSubmission memory submission,
        bytes calldata signature
    ) internal {
        // Validate submission
        require(BLSYieldAggregation.validateYieldSubmission(submission), "Consensus: invalid submission");
        
        // Check if operator has already submitted
        require(!consensus.hasSubmitted[submission.operator], "Consensus: operator already submitted");
        
        // Add submission
        consensus.hasSubmitted[submission.operator] = true;
        consensus.operatorSubmissions[submission.operator]++;
        consensus.totalSubmissions++;
        
        // Update consensus yield rate (weighted average)
        consensus.consensusYieldRate = _calculateConsensusYieldRate(consensus, submission);
        consensus.lastUpdateTime = block.timestamp;
    }

    /// @notice Get consensus percentage
    /// @param consensus The consensus data
    /// @return percentage The consensus percentage in basis points
    function getConsensusPercentage(ConsensusData storage consensus) 
        internal 
        view 
        returns (uint256 percentage) 
    {
        // This would query the total number of registered operators in production
        uint256 totalOperators = 10; // Placeholder
        
        if (totalOperators == 0) return 0;
        
        percentage = (consensus.totalSubmissions * 10000) / totalOperators;
        return percentage;
    }

    /// @notice Get consensus yield rate
    /// @param consensus The consensus data
    /// @return yieldRate The consensus yield rate
    function getConsensusYieldRate(ConsensusData storage consensus) 
        internal 
        view 
        returns (uint256 yieldRate) 
    {
        return consensus.consensusYieldRate;
    }

    /// @notice Get submission count
    /// @param consensus The consensus data
    /// @return count The number of submissions
    function getSubmissionCount(ConsensusData storage consensus) 
        internal 
        view 
        returns (uint256 count) 
    {
        return consensus.totalSubmissions;
    }

    /// @notice Check if consensus is reached
    /// @param consensus The consensus data
    /// @param params The consensus parameters
    /// @return isReached Whether consensus is reached
    function isConsensusReached(
        ConsensusData storage consensus,
        ConsensusParams memory params
    ) internal view returns (bool isReached) {
        // Check minimum submissions
        if (consensus.totalSubmissions < params.minSubmissions) {
            return false;
        }
        
        // Check consensus threshold
        uint256 consensusPercentage = getConsensusPercentage(consensus);
        if (consensusPercentage < params.consensusThreshold) {
            return false;
        }
        
        // Check staleness
        if (block.timestamp - consensus.lastUpdateTime > params.stalenessThreshold) {
            return false;
        }
        
        return true;
    }

    /// @notice Calculate consensus yield rate
    /// @param consensus The consensus data
    /// @param newSubmission The new submission
    /// @return consensusRate The consensus yield rate
    function _calculateConsensusYieldRate(
        ConsensusData storage consensus,
        BLSYieldAggregation.YieldSubmission memory newSubmission
    ) internal view returns (uint256 consensusRate) {
        // Simple average for now
        // In production, this would use weighted averages based on operator stakes
        if (consensus.totalSubmissions == 1) {
            return newSubmission.yieldRate;
        }
        
        // Calculate new average
        uint256 totalYield = consensus.consensusYieldRate * (consensus.totalSubmissions - 1);
        totalYield += newSubmission.yieldRate;
        
        consensusRate = totalYield / consensus.totalSubmissions;
        return consensusRate;
    }

    /// @notice Validate consensus data
    /// @param consensus The consensus data
    /// @param params The consensus parameters
    /// @return isValid Whether the consensus data is valid
    function validateConsensusData(
        ConsensusData storage consensus,
        ConsensusParams memory params
    ) internal view returns (bool isValid) {
        // Check basic validity
        if (consensus.lstToken == address(0)) return false;
        if (consensus.totalSubmissions == 0) return false;
        if (consensus.consensusYieldRate == 0) return false;
        
        // Check staleness
        if (block.timestamp - consensus.lastUpdateTime > params.stalenessThreshold) {
            return false;
        }
        
        // Check consensus threshold
        uint256 consensusPercentage = getConsensusPercentage(consensus);
        if (consensusPercentage < params.consensusThreshold) {
            return false;
        }
        
        return true;
    }

    /// @notice Reset consensus data
    /// @param consensus The consensus data
    function resetConsensus(ConsensusData storage consensus) internal {
        consensus.totalSubmissions = 0;
        consensus.consensusYieldRate = 0;
        consensus.lastUpdateTime = 0;
        
        // Note: We can't iterate through mappings to reset them
        // In production, you'd need to track operators separately
    }

    /// @notice Get default consensus parameters
    /// @return params The default consensus parameters
    function getDefaultConsensusParams() internal pure returns (ConsensusParams memory params) {
        params.minSubmissions = 3;
        params.consensusThreshold = 6700; // 67%
        params.maxDeviation = 1000; // 10%
        params.stalenessThreshold = 3600; // 1 hour
        return params;
    }
}
