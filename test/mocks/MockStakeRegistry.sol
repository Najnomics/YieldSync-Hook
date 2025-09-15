// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockStakeRegistry {
    mapping(address => mapping(uint8 => uint96)) public operatorStakeInQuorum;
    mapping(address => mapping(uint8 => bool)) public operatorInQuorum;
    mapping(uint8 => uint96) public totalStakeInQuorum;
    
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    function registerOperator(
        address operator,
        bytes32 operatorId,
        bytes calldata quorumNumbers
    ) external {
        for (uint i = 0; i < quorumNumbers.length; i++) {
            uint8 quorumNumber = uint8(quorumNumbers[i]);
            operatorInQuorum[operator][quorumNumber] = true;
            operatorStakeInQuorum[operator][quorumNumber] = 1000000; // Mock stake
            totalStakeInQuorum[quorumNumber] += 1000000;
        }
    }
    
    function deregisterOperator(
        address operator,
        bytes calldata quorumNumbers
    ) external {
        for (uint i = 0; i < quorumNumbers.length; i++) {
            uint8 quorumNumber = uint8(quorumNumbers[i]);
            uint96 stake = operatorStakeInQuorum[operator][quorumNumber];
            operatorInQuorum[operator][quorumNumber] = false;
            operatorStakeInQuorum[operator][quorumNumber] = 0;
            totalStakeInQuorum[quorumNumber] -= stake;
        }
    }
    
    function updateOperatorStake(
        address operator,
        uint8 quorumNumber,
        uint96 newStake
    ) external {
        if (operatorInQuorum[operator][quorumNumber]) {
            uint96 oldStake = operatorStakeInQuorum[operator][quorumNumber];
            operatorStakeInQuorum[operator][quorumNumber] = newStake;
            totalStakeInQuorum[quorumNumber] = totalStakeInQuorum[quorumNumber] - oldStake + newStake;
        }
    }
    
    function getOperatorStake(address operator, uint8 quorumNumber) 
        external 
        view 
        returns (uint96) 
    {
        return operatorStakeInQuorum[operator][quorumNumber];
    }
    
    function getTotalStake(uint8 quorumNumber) external view returns (uint96) {
        return totalStakeInQuorum[quorumNumber];
    }
    
    function isOperatorInQuorum(address operator, uint8 quorumNumber) 
        external 
        view 
        returns (bool) 
    {
        return operatorInQuorum[operator][quorumNumber];
    }
}