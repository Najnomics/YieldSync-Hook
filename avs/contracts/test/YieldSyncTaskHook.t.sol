// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {YieldSyncTaskHook} from "../src/l2-contracts/YieldSyncTaskHook.sol";
import {ITaskMailboxTypes} from "@eigenlayer-contracts/src/contracts/interfaces/ITaskMailbox.sol";

contract YieldSyncTaskHookTest is Test {
    YieldSyncTaskHook public taskHook;
    
    // Mock addresses
    address public constant MOCK_YIELDSYNC_HOOK = address(0x1);
    address public constant MOCK_SERVICE_MANAGER = address(0x2);
    address public constant MOCK_CALLER = address(0x3);
    
    function setUp() public {
        taskHook = new YieldSyncTaskHook(MOCK_YIELDSYNC_HOOK, MOCK_SERVICE_MANAGER);
        
        vm.label(MOCK_YIELDSYNC_HOOK, "MainYieldSyncHook");
        vm.label(MOCK_SERVICE_MANAGER, "ServiceManager");
        vm.label(MOCK_CALLER, "TaskCaller");
    }
    
    function testTaskHookDeployment() public {
        assertEq(taskHook.getYieldSyncHook(), MOCK_YIELDSYNC_HOOK);
        console.log("Task hook correctly references main YieldSync hook");
    }
    
    function testTaskTypeConstants() public {
        bytes32[] memory supportedTypes = taskHook.getSupportedTaskTypes();
        
        assertEq(supportedTypes.length, 5);
        console.log("Supports 5 YieldSync task types");
        
        // Test that task types are properly defined
        assertTrue(supportedTypes[0] != bytes32(0), "YIELD_MONITORING type defined");
        assertTrue(supportedTypes[1] != bytes32(0), "POSITION_ADJUSTMENT type defined");
        assertTrue(supportedTypes[2] != bytes32(0), "RISK_ASSESSMENT type defined");
        assertTrue(supportedTypes[3] != bytes32(0), "REBALANCING type defined");
        assertTrue(supportedTypes[4] != bytes32(0), "LST_VALIDATION type defined");
    }
    
    function testTaskFeeStructure() public {
        bytes32 monitoringType = keccak256("YIELD_MONITORING");
        uint96 fee = taskHook.getTaskTypeFee(monitoringType);
        
        assertGt(fee, 0, "Yield monitoring task should have non-zero fee");
        console.log("Yield monitoring task fee:", fee);
        
        bytes32 rebalancingType = keccak256("REBALANCING");
        uint96 rebalancingFee = taskHook.getTaskTypeFee(rebalancingType);
        
        assertGt(rebalancingFee, fee, "Rebalancing should cost more than monitoring");
        console.log("Rebalancing task fee:", rebalancingFee);
        
        bytes32 positionAdjustmentType = keccak256("POSITION_ADJUSTMENT");
        uint96 positionFee = taskHook.getTaskTypeFee(positionAdjustmentType);
        
        assertGt(positionFee, fee, "Position adjustment should cost more than monitoring");
        console.log("Position adjustment task fee:", positionFee);
    }
    
    function testTaskValidationBasic() public {
        // Create a minimal task params structure
        bytes memory payload = abi.encodePacked(keccak256("YIELD_MONITORING"));
        
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            payload: payload
        });
        
        // This should not revert for valid task type
        try taskHook.validatePreTaskCreation(MOCK_CALLER, taskParams) {
            console.log("Basic yield monitoring task validation passed");
        } catch {
            fail("Basic task validation should not revert");
        }
    }
    
    function testConnectorPattern() public {
        // Test that this is a connector, not business logic
        console.log("Testing L2 YieldSync connector pattern");
        
        // The task hook should:
        // 1. Interface with EigenLayer task system
        // 2. Reference the main YieldSync hook (business logic)
        // 3. NOT implement yield monitoring logic itself
        
        assertEq(taskHook.getYieldSyncHook(), MOCK_YIELDSYNC_HOOK, "Should reference main YieldSync hook");
        
        // Test that it calculates fees (coordination function)
        bytes memory payload = abi.encodePacked(keccak256("YIELD_MONITORING"));
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            payload: payload
        });
        
        uint96 fee = taskHook.calculateTaskFee(taskParams);
        assertGt(fee, 0, "Should calculate task fees");
        
        console.log("L2 YieldSync connector pattern test passed");
    }
    
    function testLSTValidationTaskType() public {
        // Test LST validation task specifically
        bytes memory payload = abi.encodePacked(keccak256("LST_VALIDATION"));
        
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            payload: payload
        });
        
        // Should not revert for LST validation task
        try taskHook.validatePreTaskCreation(MOCK_CALLER, taskParams) {
            console.log("LST validation task validation passed");
        } catch {
            fail("LST validation task should be valid");
        }
        
        // Test fee calculation
        uint96 fee = taskHook.calculateTaskFee(taskParams);
        assertGt(fee, 0, "LST validation should have non-zero fee");
        console.log("LST validation task fee:", fee);
    }
    
    function testInvalidTaskType() public {
        bytes memory invalidPayload = abi.encodePacked(keccak256("INVALID_TYPE"));
        
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            payload: invalidPayload
        });
        
        // Should revert for unsupported task type
        vm.expectRevert("Unsupported task type");
        taskHook.validatePreTaskCreation(MOCK_CALLER, taskParams);
        
        console.log("Invalid task type properly rejected");
    }
}