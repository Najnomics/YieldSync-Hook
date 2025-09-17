// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IKeyRegistrar} from "@eigenlayer-contracts/src/contracts/interfaces/IKeyRegistrar.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {TaskAVSRegistrarBase} from "@eigenlayer-middleware/src/avs/task/TaskAVSRegistrarBase.sol";

/**
 * @title YieldSyncServiceManager
 * @notice EigenLayer L1 service manager for YieldSync AVS
 * @dev This is a CONNECTOR contract that manages EigenLayer integration only.
 * The actual YieldSync business logic remains in the main YieldSyncHook contract.
 * This contract handles:
 * - Operator registration with EigenLayer for LST yield monitoring
 * - Staking management for yield data validators
 * - Task validation for yield monitoring and position adjustment tasks
 */
contract YieldSyncServiceManager is TaskAVSRegistrarBase {
    
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Address of the main YieldSync Hook contract
    address public immutable yieldSyncHook;
    
    /// @notice Minimum stake required for YieldSync yield monitoring operators
    uint256 public constant MINIMUM_YIELD_MONITORING_STAKE = 10 ether;
    
    /// @notice Supported LST tokens for yield monitoring
    mapping(address => bool) public supportedLSTTokens;
    
    /// @notice LST yield data aggregation
    mapping(address => uint256) public lastYieldUpdate;
    mapping(address => uint256) public currentYieldRate;
    
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event YieldMonitoringOperatorRegistered(address indexed operator, bytes32 indexed operatorId);
    event YieldMonitoringOperatorDeregistered(address indexed operator, bytes32 indexed operatorId);
    event YieldSyncHookUpdated(address indexed oldHook, address indexed newHook);
    event LSTTokenSupported(address indexed lstToken, bool supported);
    event YieldDataSubmitted(address indexed lstToken, uint256 yieldRate, address indexed operator);
    
    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @dev Constructor that passes parameters to parent TaskAVSRegistrarBase
     * @param _allocationManager The AllocationManager contract address
     * @param _keyRegistrar The KeyRegistrar contract address
     * @param _permissionController The PermissionController contract address
     * @param _yieldSyncHook The address of the main YieldSync Hook contract
     */
    constructor(
        IAllocationManager _allocationManager,
        IKeyRegistrar _keyRegistrar,
        IPermissionController _permissionController,
        address _yieldSyncHook
    ) TaskAVSRegistrarBase(_allocationManager, _keyRegistrar, _permissionController) {
        require(_yieldSyncHook != address(0), "Invalid YieldSync hook address");
        yieldSyncHook = _yieldSyncHook;
        
        // Initialize supported LST tokens
        // stETH
        supportedLSTTokens[0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84] = true;
        // rETH  
        supportedLSTTokens[0xae78736Cd615f374D3085123A210448E74Fc6393] = true;
        // cbETH
        supportedLSTTokens[0xBe9895146f7AF43049ca1c1AE358B0541Ea49704] = true;
        // sfrxETH
        supportedLSTTokens[0xac3E018457B222d93114458476f3E3416Abbe38F] = true;
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @dev Initializer that calls parent initializer
     * @param _avs The address of the AVS
     * @param _owner The owner of the contract
     * @param _initialConfig The initial AVS configuration
     */
    function initialize(address _avs, address _owner, AvsConfig memory _initialConfig) external initializer {
        __TaskAVSRegistrarBase_init(_avs, _owner, _initialConfig);
    }

    /*//////////////////////////////////////////////////////////////
                     YIELDSYNC-SPECIFIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register an operator specifically for YieldSync yield monitoring tasks
     * @dev This extends the base registration with YieldSync-specific requirements
     * @param operator The operator address to register
     * @param operatorSignature The operator's signature for EigenLayer
     */
    function registerYieldMonitoringOperator(
        address operator,
        bytes calldata operatorSignature
    ) external payable {
        require(msg.value >= MINIMUM_YIELD_MONITORING_STAKE, "Insufficient stake for yield monitoring operations");
        
        // Call parent registration logic (handles EigenLayer integration)
        _registerOperator(operator, operatorSignature);
        
        bytes32 operatorId = keccak256(abi.encodePacked(operator, block.timestamp));
        emit YieldMonitoringOperatorRegistered(operator, operatorId);
    }

    /**
     * @notice Deregister an operator from YieldSync yield monitoring tasks
     * @param operator The operator address to deregister
     */
    function deregisterYieldMonitoringOperator(address operator) external {
        // Call parent deregistration logic
        _deregisterOperator(operator);
        
        bytes32 operatorId = keccak256(abi.encodePacked(operator, block.timestamp));
        emit YieldMonitoringOperatorDeregistered(operator, operatorId);
    }

    /**
     * @notice Check if an operator meets YieldSync yield monitoring requirements
     * @param operator The operator address to check
     * @return Whether the operator is qualified for yield monitoring
     */
    function isYieldMonitoringOperatorQualified(address operator) external view returns (bool) {
        // Check base registration status and add YieldSync-specific checks
        return _isRegistered(operator) && _getOperatorStake(operator) >= MINIMUM_YIELD_MONITORING_STAKE;
    }

    /**
     * @notice Submit yield data for an LST token (operator only)
     * @param lstToken The LST token address
     * @param yieldRate The current yield rate in basis points
     */
    function submitYieldData(address lstToken, uint256 yieldRate) external {
        require(_isRegistered(msg.sender), "Operator not registered");
        require(supportedLSTTokens[lstToken], "LST token not supported");
        require(yieldRate <= 50000, "Yield rate too high"); // Max 500% sanity check
        
        currentYieldRate[lstToken] = yieldRate;
        lastYieldUpdate[lstToken] = block.timestamp;
        
        emit YieldDataSubmitted(lstToken, yieldRate, msg.sender);
    }

    /**
     * @notice Add or remove support for an LST token
     * @param lstToken The LST token address
     * @param supported Whether the token should be supported
     */
    function setLSTTokenSupport(address lstToken, bool supported) external {
        // TODO: Add proper access control (onlyOwner or governance)
        supportedLSTTokens[lstToken] = supported;
        emit LSTTokenSupported(lstToken, supported);
    }

    /**
     * @notice Get the YieldSync Hook contract address
     * @return The address of the main YieldSync logic contract
     */
    function getYieldSyncHook() external view returns (address) {
        return yieldSyncHook;
    }

    /**
     * @notice Get current yield rate for an LST token
     * @param lstToken The LST token address
     * @return yieldRate The current yield rate in basis points
     * @return lastUpdate The timestamp of the last update
     */
    function getYieldData(address lstToken) external view returns (uint256 yieldRate, uint256 lastUpdate) {
        return (currentYieldRate[lstToken], lastYieldUpdate[lstToken]);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to check operator registration
     * @param operator The operator address
     * @return Whether the operator is registered
     */
    function _isRegistered(address operator) internal view returns (bool) {
        // Implementation depends on TaskAVSRegistrarBase structure
        // This is a placeholder - actual implementation would check registration status
        return true; // TODO: Implement based on TaskAVSRegistrarBase
    }

    /**
     * @notice Internal function to get operator stake
     * @param operator The operator address
     * @return The operator's stake amount
     */
    function _getOperatorStake(address operator) internal view returns (uint256) {
        // Implementation depends on TaskAVSRegistrarBase structure  
        // This is a placeholder - actual implementation would return stake
        return 0; // TODO: Implement based on TaskAVSRegistrarBase
    }
}