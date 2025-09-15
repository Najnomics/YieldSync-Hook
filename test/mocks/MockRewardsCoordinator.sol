// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockRewardsCoordinator {
    mapping(address => uint256) public operatorRewards;
    mapping(address => mapping(address => uint256)) public operatorTokenRewards;
    
    address public owner;
    uint256 public totalRewardsDistributed;
    
    constructor() {
        owner = msg.sender;
    }
    
    function createAVSRewardsSubmission(
        address[] calldata rewardsSubmissions
    ) external {
        // Mock implementation - just increment total rewards
        totalRewardsDistributed += rewardsSubmissions.length * 1000000;
    }
    
    function submitRewards(
        address operator,
        address token,
        uint256 amount
    ) external {
        operatorRewards[operator] += amount;
        operatorTokenRewards[operator][token] += amount;
        totalRewardsDistributed += amount;
    }
    
    function claimRewards(
        address operator,
        address token,
        uint256 amount
    ) external {
        require(operatorTokenRewards[operator][token] >= amount, "Insufficient rewards");
        operatorTokenRewards[operator][token] -= amount;
        operatorRewards[operator] -= amount;
        // In a real implementation, this would transfer tokens
    }
    
    function getOperatorRewards(address operator) 
        external 
        view 
        returns (uint256) 
    {
        return operatorRewards[operator];
    }
    
    function getOperatorTokenRewards(address operator, address token) 
        external 
        view 
        returns (uint256) 
    {
        return operatorTokenRewards[operator][token];
    }
    
    function calculateRewards(
        address operator,
        address[] calldata strategies,
        uint256[] calldata amounts
    ) external view returns (uint256 totalReward) {
        // Mock calculation - just sum the amounts
        for (uint i = 0; i < amounts.length; i++) {
            totalReward += amounts[i];
        }
        return totalReward / 10; // Mock 10% reward rate
    }
}