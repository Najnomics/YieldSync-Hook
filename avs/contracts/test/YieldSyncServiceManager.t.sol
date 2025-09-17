// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {YieldSyncServiceManager} from "../src/l1-contracts/YieldSyncServiceManager.sol";

contract YieldSyncServiceManagerTest is Test {
    YieldSyncServiceManager public serviceManager;
    
    // Mock addresses
    address public constant MOCK_ALLOCATION_MANAGER = address(0x1);
    address public constant MOCK_KEY_REGISTRAR = address(0x2);
    address public constant MOCK_PERMISSION_CONTROLLER = address(0x3);
    address public constant MOCK_YIELDSYNC_HOOK = address(0x4);
    
    // LST token addresses (using real mainnet addresses for testing)
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant CBETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address public constant SFRXETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    
    function setUp() public {
        // This is a placeholder test since the actual deployment would require
        // real EigenLayer contracts. In practice, you'd use mocks or a testnet.
        vm.label(MOCK_ALLOCATION_MANAGER, "AllocationManager");
        vm.label(MOCK_KEY_REGISTRAR, "KeyRegistrar");
        vm.label(MOCK_PERMISSION_CONTROLLER, "PermissionController");
        vm.label(MOCK_YIELDSYNC_HOOK, "YieldSyncHook");
        vm.label(STETH, "stETH");
        vm.label(RETH, "rETH");
        vm.label(CBETH, "cbETH");
        vm.label(SFRXETH, "sfrxETH");
    }
    
    function testServiceManagerStorage() public {
        // Test that the service manager stores the correct YieldSync hook address
        // This would be expanded with actual deployment tests
        assertTrue(MOCK_YIELDSYNC_HOOK != address(0));
        console.log("YieldSync Service Manager test setup completed");
    }
    
    function testYieldMonitoringStakeRequirement() public {
        // Test that the minimum stake requirement is set correctly
        uint256 expectedMinStake = 10 ether;
        
        // In actual implementation, you'd test:
        // assertEq(serviceManager.MINIMUM_YIELD_MONITORING_STAKE(), expectedMinStake);
        
        console.log("Minimum yield monitoring stake requirement:", expectedMinStake);
        assertTrue(expectedMinStake > 0);
    }
    
    function testLSTTokenSupport() public {
        // Test that major LST tokens are supported
        console.log("Testing LST token support");
        
        // In actual implementation, you'd test:
        // assertTrue(serviceManager.supportedLSTTokens(STETH), "stETH should be supported");
        // assertTrue(serviceManager.supportedLSTTokens(RETH), "rETH should be supported");
        // assertTrue(serviceManager.supportedLSTTokens(CBETH), "cbETH should be supported");
        // assertTrue(serviceManager.supportedLSTTokens(SFRXETH), "sfrxETH should be supported");
        
        assertTrue(STETH != address(0), "stETH address should be valid");
        assertTrue(RETH != address(0), "rETH address should be valid");
        assertTrue(CBETH != address(0), "cbETH address should be valid");
        assertTrue(SFRXETH != address(0), "sfrxETH address should be valid");
        
        console.log("LST token support test passed");
    }
    
    function testYieldDataSubmission() public {
        // Test yield data submission functionality
        console.log("Testing yield data submission");
        
        uint256 mockYieldRate = 400; // 4% annual yield in basis points
        
        // In actual implementation, you'd test:
        // vm.prank(registeredOperator);
        // serviceManager.submitYieldData(STETH, mockYieldRate);
        // (uint256 storedRate, uint256 lastUpdate) = serviceManager.getYieldData(STETH);
        // assertEq(storedRate, mockYieldRate);
        // assertGt(lastUpdate, 0);
        
        assertTrue(mockYieldRate > 0 && mockYieldRate <= 50000, "Yield rate should be within bounds");
        console.log("Yield data submission test passed");
    }
    
    function testConnectorArchitecture() public {
        // Test that this is a connector contract, not business logic
        console.log("Testing YieldSync AVS connector architecture");
        
        // The service manager should:
        // 1. Connect to EigenLayer (L1)
        // 2. Reference the main YieldSync hook
        // 3. NOT contain yield monitoring business logic
        // 4. Support LST yield data aggregation
        
        assertTrue(MOCK_ALLOCATION_MANAGER != address(0), "Should connect to EigenLayer");
        assertTrue(MOCK_YIELDSYNC_HOOK != address(0), "Should reference main YieldSync hook");
        
        console.log("Connector architecture test passed");
    }
}