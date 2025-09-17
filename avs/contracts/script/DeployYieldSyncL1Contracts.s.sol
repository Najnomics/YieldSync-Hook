// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IKeyRegistrar} from "@eigenlayer-contracts/src/contracts/interfaces/IKeyRegistrar.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";

import {YieldSyncServiceManager} from "../src/l1-contracts/YieldSyncServiceManager.sol";

contract DeployYieldSyncL1Contracts is Script {
    using stdJson for string;

    struct Context {
        address avs;
        uint256 avsPrivateKey;
        uint256 deployerPrivateKey;
        IAllocationManager allocationManager;
        IKeyRegistrar keyRegistrar;
        IPermissionController permissionController;
        address yieldSyncHook;
    }

    struct Output {
        string name;
        address contractAddress;
    }

    function run(string memory environment, string memory _context) public {
        // Read the context
        Context memory context = _readContext(environment, _context);

        vm.startBroadcast(context.deployerPrivateKey);
        console.log("Deployer address:", vm.addr(context.deployerPrivateKey));

        // Deploy YieldSync Service Manager
        YieldSyncServiceManager yieldSyncServiceManager = new YieldSyncServiceManager(
            context.allocationManager,
            context.keyRegistrar,
            context.permissionController,
            context.yieldSyncHook
        );
        console.log("YieldSyncServiceManager deployed to:", address(yieldSyncServiceManager));

        vm.stopBroadcast();

        vm.startBroadcast(context.avsPrivateKey);
        console.log("AVS address:", context.avs);

        // Initialize YieldSync Service Manager
        // TODO: Define proper AvsConfig structure
        // yieldSyncServiceManager.initialize(
        //     context.avs,
        //     context.avs,
        //     initialConfig
        // );

        // TODO: Implement any additional AVS setup for YieldSync
        // - Configure yield monitoring parameters
        // - Set up reward mechanisms for yield operators
        // - Initialize LST token support
        // - Set minimum stake requirements

        vm.stopBroadcast();

        // Output the deployed contracts
        Output[] memory outputs = new Output[](1);
        outputs[0] = Output("YieldSyncServiceManager", address(yieldSyncServiceManager));

        _writeOutput(environment, outputs);
    }

    function _readContext(string memory environment, string memory _context) internal view returns (Context memory) {
        string memory contextJson = vm.readFile(string.concat(".hourglass/context/", environment, ".json"));

        Context memory context;
        context.avs = contextJson.readAddress(".avs.address");
        context.avsPrivateKey = contextJson.readUint(".avs.privateKey");
        context.deployerPrivateKey = contextJson.readUint(".deployer.privateKey");
        context.allocationManager = IAllocationManager(contextJson.readAddress(".contracts.allocationManager"));
        context.keyRegistrar = IKeyRegistrar(contextJson.readAddress(".contracts.keyRegistrar"));
        context.permissionController = IPermissionController(contextJson.readAddress(".contracts.permissionController"));
        context.yieldSyncHook = contextJson.readAddress(".contracts.yieldSyncHook");

        return context;
    }

    function _writeOutput(string memory environment, Output[] memory outputs) internal {
        string memory outputDir = string.concat(".hourglass/context/", environment, "/");
        string memory outputFile = string.concat(outputDir, "l1-contracts.json");

        string memory json = "";
        for (uint256 i = 0; i < outputs.length; i++) {
            json = vm.serializeAddress(json, outputs[i].name, outputs[i].contractAddress);
        }

        vm.writeFile(outputFile, json);
        console.log("L1 contract addresses written to:", outputFile);
    }
}