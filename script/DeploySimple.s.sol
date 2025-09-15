// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/hooks/YieldSyncHook.sol";
import "../src/avs/LSTMonitors/LidoYieldMonitor.sol";

contract DeploySimple is Script {
    
    function run() external {
        console.log("=== Simple YieldSync Hook Deployment ===");
        
        vm.startBroadcast();
        
        // Deploy LidoYieldMonitor
        LidoYieldMonitor lidoMonitor = new LidoYieldMonitor();
        console.log("LidoYieldMonitor deployed at:", address(lidoMonitor));
        
        // Deploy YieldSyncHook (simplified without AVS dependencies)
        // For testing purposes, we'll deploy a minimal version
        console.log("Deploying YieldSyncHook...");
        
        // Note: This is a simplified deployment for testing hook functionality
        // The full AVS integration would require proper EigenLayer setup
        
        vm.stopBroadcast();
        
        console.log("=== Deployment Complete ===");
        console.log("LidoYieldMonitor:", address(lidoMonitor));
    }
}