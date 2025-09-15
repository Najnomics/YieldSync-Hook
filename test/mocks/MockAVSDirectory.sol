// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockAVSDirectory {
    mapping(address => bool) public avsOperatorStatus;
    mapping(address => mapping(address => bool)) public operatorAVSRegistrations;
    
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    function registerOperatorToAVS(
        address operator,
        bytes calldata operatorSignature
    ) external {
        operatorAVSRegistrations[msg.sender][operator] = true;
        avsOperatorStatus[operator] = true;
    }
    
    function deregisterOperatorFromAVS(address operator) external {
        operatorAVSRegistrations[msg.sender][operator] = false;
        avsOperatorStatus[operator] = false;
    }
    
    function updateAVSMetadataURI(string calldata metadataURI) external {
        // Mock implementation
    }
    
    function isOperatorRegistered(address avs, address operator) 
        external 
        view 
        returns (bool) 
    {
        return operatorAVSRegistrations[avs][operator];
    }
    
    function getOperatorRestakedStrategies(address operator) 
        external 
        view 
        returns (address[] memory) 
    {
        return new address[](0);
    }
    
    function getRestakeableStrategies() external view returns (address[] memory) {
        return new address[](0);
    }
}