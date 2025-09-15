// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/avs/interfaces/ILSTYieldMonitor.sol";

contract MockLSTYieldMonitor is ILSTYieldMonitor {
    uint256 public mockYieldRate = 500; // 5%
    bool public mockIsValid = true;
    address public mockLSTToken = 0xae78736Cd615f374D3085123A210448E74Fc6393; // rETH
    bool private _paused;
    
    function verifyYieldProof(uint256 yieldRate, bytes calldata proof) 
        external 
        view 
        returns (bool isValid) 
    {
        return mockIsValid;
    }
    
    function getExpectedYieldRange() 
        external 
        pure 
        returns (uint256 minYield, uint256 maxYield) 
    {
        return (300, 700); // 3-7%
    }
    
    function name() external pure returns (string memory) {
        return "Mock LST Monitor";
    }
    
    function lstToken() external view returns (address) {
        return mockLSTToken;
    }
    
    function paused() external view returns (bool) {
        return _paused;
    }
    
    // Mock control functions
    function setMockYieldRate(uint256 newRate) external {
        mockYieldRate = newRate;
    }
    
    function setMockIsValid(bool isValid) external {
        mockIsValid = isValid;
    }
    
    function setMockLSTToken(address token) external {
        mockLSTToken = token;
    }
    
    function setPaused(bool paused_) external {
        _paused = paused_;
    }
}