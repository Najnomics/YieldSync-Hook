// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/avs/LSTMonitors/LidoYieldMonitor.sol";
import "../src/avs/LSTMonitors/RocketPoolMonitor.sol";
import "../src/avs/LSTMonitors/CoinbaseMonitor.sol";
import "../src/avs/LSTMonitors/FraxMonitor.sol";

contract DeployCore is Script {
    
    function run() external {
        console.log("=== Core YieldSync Components Deployment ===");
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast();
        
        // Deploy LST Monitors
        console.log("Deploying LST Monitors...");
        
        LidoYieldMonitor lidoMonitor = new LidoYieldMonitor();
        console.log("LidoYieldMonitor deployed at:", address(lidoMonitor));
        
        RocketPoolMonitor rocketPoolMonitor = new RocketPoolMonitor();
        console.log("RocketPoolMonitor deployed at:", address(rocketPoolMonitor));
        
        CoinbaseMonitor coinbaseMonitor = new CoinbaseMonitor();
        console.log("CoinbaseMonitor deployed at:", address(coinbaseMonitor));
        
        FraxMonitor fraxMonitor = new FraxMonitor();
        console.log("FraxMonitor deployed at:", address(fraxMonitor));
        
        vm.stopBroadcast();
        
        console.log("=== Core Deployment Complete ===");
        console.log("All LST monitors deployed successfully!");
        
        // Test basic functionality
        console.log("\n=== Testing Basic Functionality ===");
        console.log("LidoYieldMonitor stETH address:", lidoMonitor.stETH());
        console.log("RocketPoolMonitor rETH address:", rocketPoolMonitor.rETH());
        console.log("LidoYieldMonitor owner:", lidoMonitor.owner());
        console.log("LidoYieldMonitor paused:", lidoMonitor.paused());
    }
}