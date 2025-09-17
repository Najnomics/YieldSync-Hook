// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IAVSTaskHook} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSTaskHook.sol";
import {ITaskMailboxTypes} from "@eigenlayer-contracts/src/contracts/interfaces/ITaskMailbox.sol";

/**
 * @title YieldSyncTaskHook
 * @notice L2 task hook that interfaces between EigenLayer task system and main YieldSync Hook
 * @dev This is a CONNECTOR contract that:
 * - Validates task parameters for YieldSync yield monitoring operations
 * - Calculates fees for different task types
 * - Interfaces with the main YieldSyncHook contract (deployed separately)
 * - Does NOT contain yield monitoring business logic itself
 */
contract YieldSyncTaskHook is IAVSTaskHook {
    
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Address of the main YieldSync Hook contract
    address public immutable yieldSyncHook;
    
    /// @notice Address of the L1 service manager
    address public immutable serviceManager;
    
    /// @notice Task type constants
    bytes32 public constant TASK_TYPE_YIELD_MONITORING = keccak256("YIELD_MONITORING");
    bytes32 public constant TASK_TYPE_POSITION_ADJUSTMENT = keccak256("POSITION_ADJUSTMENT");
    bytes32 public constant TASK_TYPE_RISK_ASSESSMENT = keccak256("RISK_ASSESSMENT");
    bytes32 public constant TASK_TYPE_REBALANCING = keccak256("REBALANCING");
    bytes32 public constant TASK_TYPE_LST_VALIDATION = keccak256("LST_VALIDATION");
    
    /// @notice Fee structure for different task types
    mapping(bytes32 => uint96) public taskTypeFees;
    
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event TaskValidated(bytes32 indexed taskHash, bytes32 taskType, address caller);
    event TaskCreated(bytes32 indexed taskHash, bytes32 taskType);
    event TaskResultSubmitted(bytes32 indexed taskHash, address caller);
    event TaskFeeCalculated(bytes32 indexed taskHash, bytes32 taskType, uint96 fee);
    event YieldSyncHookUpdated(address indexed oldHook, address indexed newHook);
    event YieldDataValidated(address indexed lstToken, uint256 yieldRate, bool isValid);
    
    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    
    modifier onlyServiceManager() {
        require(msg.sender == serviceManager, "Only service manager can call");
        _;
    }
    
    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @param _yieldSyncHook Address of the main YieldSync Hook contract
     * @param _serviceManager Address of the L1 service manager
     */
    constructor(address _yieldSyncHook, address _serviceManager) {
        require(_yieldSyncHook != address(0), "Invalid YieldSync hook");
        require(_serviceManager != address(0), "Invalid service manager");
        
        yieldSyncHook = _yieldSyncHook;
        serviceManager = _serviceManager;
        
        // Initialize default fees (in wei)
        taskTypeFees[TASK_TYPE_YIELD_MONITORING] = 0.001 ether;      // 0.001 ETH
        taskTypeFees[TASK_TYPE_POSITION_ADJUSTMENT] = 0.005 ether;   // 0.005 ETH
        taskTypeFees[TASK_TYPE_RISK_ASSESSMENT] = 0.002 ether;       // 0.002 ETH
        taskTypeFees[TASK_TYPE_REBALANCING] = 0.01 ether;            // 0.01 ETH
        taskTypeFees[TASK_TYPE_LST_VALIDATION] = 0.003 ether;        // 0.003 ETH
    }
    
    /*//////////////////////////////////////////////////////////////
                            IAVSTaskHook IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Validate task parameters before task creation
     * @param caller The address creating the task
     * @param taskParams The task parameters
     */
    function validatePreTaskCreation(
        address caller,
        ITaskMailboxTypes.TaskParams memory taskParams
    ) external view override {
        // Extract task type from payload
        bytes32 taskType = _extractTaskType(taskParams.payload);
        
        // Validate task type is supported
        require(_isValidTaskType(taskType), "Unsupported task type");
        
        // Validate caller permissions (could check with service manager)
        require(caller != address(0), "Invalid caller");
        
        // Additional YieldSync-specific validations based on task type
        if (taskType == TASK_TYPE_YIELD_MONITORING) {
            _validateYieldMonitoringTask(taskParams.payload);
        } else if (taskType == TASK_TYPE_POSITION_ADJUSTMENT) {
            _validatePositionAdjustmentTask(taskParams.payload);
        } else if (taskType == TASK_TYPE_RISK_ASSESSMENT) {
            _validateRiskAssessmentTask(taskParams.payload);
        } else if (taskType == TASK_TYPE_REBALANCING) {
            _validateRebalancingTask(taskParams.payload);
        } else if (taskType == TASK_TYPE_LST_VALIDATION) {
            _validateLSTValidationTask(taskParams.payload);
        }
        
        emit TaskValidated(keccak256(abi.encode(taskParams)), taskType, caller);
    }
    
    /**
     * @notice Handle post-task creation logic
     * @param taskHash The hash of the created task
     */
    function handlePostTaskCreation(bytes32 taskHash) external override {
        // Could notify the main YieldSync Hook about new tasks
        // For now, just emit an event
        emit TaskCreated(taskHash, bytes32(0)); // Task type would need to be stored/retrieved
    }
    
    /**
     * @notice Validate task result before submission
     * @param caller The address submitting the result
     * @param taskHash The task hash
     * @param cert The certificate (if any)
     * @param result The task result
     */
    function validatePreTaskResultSubmission(
        address caller,
        bytes32 taskHash,
        bytes memory cert,
        bytes memory result
    ) external view override {
        // Validate caller is authorized (could check with service manager)
        require(caller != address(0), "Invalid caller");
        
        // Validate result format based on task type
        require(result.length > 0, "Empty result");
        
        // Additional validation logic could be added here
        // For example, validate result format matches expected structure
    }
    
    /**
     * @notice Handle post-task result submission
     * @param caller The address that submitted the result
     * @param taskHash The task hash
     */
    function handlePostTaskResultSubmission(
        address caller,
        bytes32 taskHash
    ) external override {
        // Could trigger actions in the main YieldSync Hook
        // For now, just emit an event
        emit TaskResultSubmitted(taskHash, caller);
    }
    
    /**
     * @notice Calculate fee for a task
     * @param taskParams The task parameters
     * @return The calculated fee in wei
     */
    function calculateTaskFee(
        ITaskMailboxTypes.TaskParams memory taskParams
    ) external view override returns (uint96) {
        bytes32 taskType = _extractTaskType(taskParams.payload);
        uint96 fee = taskTypeFees[taskType];
        
        // Could add dynamic fee calculation based on task complexity
        // For now, return fixed fee based on task type
        return fee;
    }
    
    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Extract task type from payload
     * @param payload The task payload
     * @return The task type hash
     */
    function _extractTaskType(bytes memory payload) internal pure returns (bytes32) {
        if (payload.length < 32) return bytes32(0);
        
        // Assume first 32 bytes contain task type
        bytes32 taskType;
        assembly {
            taskType := mload(add(payload, 32))
        }
        return taskType;
    }
    
    /**
     * @notice Check if task type is valid
     * @param taskType The task type to check
     * @return Whether the task type is supported
     */
    function _isValidTaskType(bytes32 taskType) internal view returns (bool) {
        return taskType == TASK_TYPE_YIELD_MONITORING ||
               taskType == TASK_TYPE_POSITION_ADJUSTMENT ||
               taskType == TASK_TYPE_RISK_ASSESSMENT ||
               taskType == TASK_TYPE_REBALANCING ||
               taskType == TASK_TYPE_LST_VALIDATION;
    }
    
    /**
     * @notice Validate yield monitoring task parameters
     * @param payload The task payload
     */
    function _validateYieldMonitoringTask(bytes memory payload) internal pure {
        // Validate that payload contains required yield monitoring parameters
        require(payload.length >= 96, "Invalid yield monitoring task payload"); // 32 + 32 + 32 minimum
        // Could add more specific validation for LST token address, threshold, etc.
    }
    
    /**
     * @notice Validate position adjustment task parameters
     * @param payload The task payload
     */
    function _validatePositionAdjustmentTask(bytes memory payload) internal pure {
        // Validate that payload contains required position adjustment parameters
        require(payload.length >= 128, "Invalid position adjustment payload"); // Minimum required fields
        // Could add validation for pool ID, position data, tick ranges, etc.
    }
    
    /**
     * @notice Validate risk assessment task parameters
     * @param payload The task payload
     */
    function _validateRiskAssessmentTask(bytes memory payload) internal pure {
        // Validate that payload contains required risk assessment parameters
        require(payload.length >= 160, "Invalid risk assessment payload"); // Risk data requirements
        // Could add validation for LST tokens, validator data, risk metrics, etc.
    }
    
    /**
     * @notice Validate rebalancing task parameters
     * @param payload The task payload
     */
    function _validateRebalancingTask(bytes memory payload) internal pure {
        // Validate that payload contains required rebalancing parameters
        require(payload.length >= 128, "Invalid rebalancing payload"); // Rebalancing requirements
        // Could add validation for portfolio data, target allocations, etc.
    }

    /**
     * @notice Validate LST validation task parameters
     * @param payload The task payload
     */
    function _validateLSTValidationTask(bytes memory payload) internal pure {
        // Validate that payload contains required LST validation parameters
        require(payload.length >= 64, "Invalid LST validation payload"); // LST validation requirements
        // Could add validation for LST token address, validation criteria, etc.
    }
    
    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Get the main YieldSync Hook address
     * @return The address of the main YieldSync logic contract
     */
    function getYieldSyncHook() external view returns (address) {
        return yieldSyncHook;
    }
    
    /**
     * @notice Get fee for a specific task type
     * @param taskType The task type
     * @return The fee for that task type
     */
    function getTaskTypeFee(bytes32 taskType) external view returns (uint96) {
        return taskTypeFees[taskType];
    }
    
    /**
     * @notice Get all supported task types
     * @return Array of supported task type hashes
     */
    function getSupportedTaskTypes() external pure returns (bytes32[] memory) {
        bytes32[] memory types = new bytes32[](5);
        types[0] = TASK_TYPE_YIELD_MONITORING;
        types[1] = TASK_TYPE_POSITION_ADJUSTMENT;
        types[2] = TASK_TYPE_RISK_ASSESSMENT;
        types[3] = TASK_TYPE_REBALANCING;
        types[4] = TASK_TYPE_LST_VALIDATION;
        return types;
    }
    
    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Update fee for a task type (only service manager)
     * @param taskType The task type to update
     * @param newFee The new fee amount
     */
    function updateTaskTypeFee(bytes32 taskType, uint96 newFee) external onlyServiceManager {
        require(_isValidTaskType(taskType), "Invalid task type");
        taskTypeFees[taskType] = newFee;
    }
}