// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ILSTYieldMonitor
 * @dev Interface for LST yield monitor contracts
 */
interface ILSTYieldMonitor {
    /**
     * @notice Verify yield proof from LST protocol
     * @param yieldRate The yield rate in basis points
     * @param proof The proof data
     * @return isValid Whether the proof is valid
     */
    function verifyYieldProof(uint256 yieldRate, bytes calldata proof) external view returns (bool isValid);
}
