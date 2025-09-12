// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@eigenlayer/contracts/../test/utils/BytesLib.sol";
import "./IYieldSyncTaskManager.sol";
import "@eigenlayer-middleware/ServiceManagerBase.sol";
import {
    IAllocationManager,
    IAllocationManagerTypes
} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {ISlashingRegistryCoordinator} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";

import "./interfaces/IYieldSyncAVS.sol";
import "./LSTMonitors/LidoYieldMonitor.sol";
import "./LSTMonitors/RocketPoolMonitor.sol";
import "./LSTMonitors/CoinbaseMonitor.sol";
import "./LSTMonitors/FraxMonitor.sol";

/**
 * @title YieldSyncServiceManager
 * @dev Primary entrypoint for procuring services from YieldSync
 * @author Layr Labs, Inc.
 */
contract YieldSyncServiceManager is ServiceManagerBase {
    using BytesLib for bytes;

    IYieldSyncTaskManager public immutable yieldSyncTaskManager;

    /// @notice when applied to a function, ensures that the function is only callable by the `registryCoordinator`.
    modifier onlyYieldSyncTaskManager() {
        require(
            msg.sender == address(yieldSyncTaskManager),
            "onlyYieldSyncTaskManager: not from yield sync task manager"
        );
        _;
    }

    constructor(
        IAVSDirectory _avsDirectory,
        ISlashingRegistryCoordinator _registryCoordinator,
        IStakeRegistry _stakeRegistry,
        address rewards_coordinator,
        IAllocationManager _allocationManager,
        IPermissionController _permissionController,
        IYieldSyncTaskManager _yieldSyncTaskManager
    )
        ServiceManagerBase(
            _avsDirectory,
            IRewardsCoordinator(rewards_coordinator),
            _registryCoordinator,
            _stakeRegistry,
            _permissionController,
            _allocationManager
        )
    {
        yieldSyncTaskManager = _yieldSyncTaskManager;
    }

    function initialize(address initialOwner, address rewardsInitiator) external initializer {
        __ServiceManagerBase_init(initialOwner, rewardsInitiator);
    }

    /// @notice Returns the registry coordinator
    function registryCoordinator() external view returns (ISlashingRegistryCoordinator) {
        return _registryCoordinator;
    }

    /// @notice Returns the stake registry
    function stakeRegistry() external view returns (IStakeRegistry) {
        return _stakeRegistry;
    }

    /// @notice Returns the rewards coordinator
    function rewardsCoordinator() external view returns (IRewardsCoordinator) {
        return _rewardsCoordinator;
    }

    /// @notice Returns the allocation manager
    function allocationManager() external view returns (IAllocationManager) {
        return _allocationManager;
    }

    /// @notice Returns the permission controller
    function permissionController() external view returns (IPermissionController) {
        return _permissionController;
    }
}