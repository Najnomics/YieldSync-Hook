// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockDelegationManager {
    mapping(address => address) public delegatedTo;
    mapping(address => bool) public isOperator;
    mapping(address => mapping(address => bool)) public operatorShares;
    mapping(address => uint256) public operatorStakes;
    
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    function registerAsOperator(
        address operator,
        string calldata metadataURI
    ) external {
        isOperator[operator] = true;
        delegatedTo[operator] = operator; // Operators delegate to themselves
    }
    
    function delegateTo(
        address operator,
        bytes calldata approverSignatureAndExpiry,
        bytes32 approverSalt
    ) external {
        require(isOperator[operator], "Not an operator");
        delegatedTo[msg.sender] = operator;
        operatorShares[operator][msg.sender] = true;
    }
    
    function undelegate(address staker) external {
        address operator = delegatedTo[staker];
        delegatedTo[staker] = address(0);
        operatorShares[operator][staker] = false;
    }
    
    function increaseDelegatedShares(
        address staker,
        address strategy,
        uint256 shares
    ) external {
        address operator = delegatedTo[staker];
        if (operator != address(0)) {
            operatorStakes[operator] += shares;
        }
    }
    
    function decreaseDelegatedShares(
        address staker,
        address strategy,
        uint256 shares
    ) external {
        address operator = delegatedTo[staker];
        if (operator != address(0)) {
            operatorStakes[operator] = operatorStakes[operator] > shares ? 
                operatorStakes[operator] - shares : 0;
        }
    }
    
    function isDelegated(address staker) external view returns (bool) {
        return delegatedTo[staker] != address(0);
    }
    
    function isOperatorRegistered(address operator) external view returns (bool) {
        return isOperator[operator];
    }
    
    function operatorDetails(address operator) 
        external 
        view 
        returns (address, string memory) 
    {
        return (operator, isOperator[operator] ? "Mock Operator" : "");
    }
    
    function getOperatorShares(
        address operator,
        address strategy
    ) external view returns (uint256) {
        return operatorStakes[operator];
    }
    
    function getDelegatedShares(
        address staker,
        address strategy
    ) external view returns (uint256) {
        return operatorStakes[delegatedTo[staker]];
    }
}