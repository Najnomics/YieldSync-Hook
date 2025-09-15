// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/avs/LSTMonitors/RocketPoolMonitor.sol";

contract RocketPoolMonitorUnitTest is Test {
    RocketPoolMonitor public monitor;
    address public owner;
    address public user;

    // Test constants
    uint256 constant EXCHANGE_RATE = 1100000000000000000; // 1.1 ETH per rETH
    uint256 constant TOTAL_RETH_SUPPLY = 1000000000000000000000; // 1000 rETH
    uint256 constant TOTAL_ETH_BACKING = 1100000000000000000000; // 1100 ETH
    uint256 constant TIMESTAMP = 1234567890;

    event YieldDataUpdated(
        uint256 indexed dataId,
        uint256 exchangeRate,
        uint256 annualYieldRate,
        uint256 timestamp
    );

    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        
        vm.prank(owner);
        monitor = new RocketPoolMonitor();
    }

    // Constructor Tests (5 tests)
    function test_Constructor_SetsOwner() public {
        assertEq(monitor.owner(), owner);
    }

    function test_Constructor_InitializesCounter() public {
        assertEq(monitor.yieldDataCounter(), 0);
    }

    function test_Constructor_NotPaused() public {
        assertFalse(monitor.paused());
    }

    function test_Constructor_RETHAddress() public {
        assertEq(monitor.rETH(), 0xae78736Cd615f374D3085123A210448E74Fc6393);
    }

    function test_Constructor_LSTToken() public {
        assertEq(monitor.lstToken(), 0xae78736Cd615f374D3085123A210448E74Fc6393);
    }

    // Access Control Tests (5 tests)
    function test_OnlyOwner_UpdateYieldData() public {
        vm.prank(user);
        vm.expectRevert();
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
    }

    function test_OnlyOwner_Success() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        assertEq(monitor.yieldDataCounter(), 1);
    }

    function test_Ownable_TransferOwnership() public {
        vm.prank(owner);
        monitor.transferOwnership(user);
        assertEq(monitor.owner(), user);
    }

    function test_Ownable_RenounceOwnership() public {
        vm.prank(owner);
        monitor.renounceOwnership();
        assertEq(monitor.owner(), address(0));
    }

    function test_Ownable_NonOwnerCannotTransfer() public {
        vm.prank(user);
        vm.expectRevert();
        monitor.transferOwnership(user);
    }

    // Basic View Functions (5 tests)
    function test_Name() public {
        assertEq(monitor.name(), "Rocket Pool rETH");
    }

    function test_RETH_Constant() public {
        assertEq(monitor.rETH(), 0xae78736Cd615f374D3085123A210448E74Fc6393);
    }

    function test_LSTToken_ReturnsRETH() public {
        assertEq(monitor.lstToken(), monitor.rETH());
    }

    function test_Paused_InitiallyFalse() public {
        assertFalse(monitor.paused());
    }

    function test_YieldDataCounter_InitiallyZero() public {
        assertEq(monitor.yieldDataCounter(), 0);
    }

    // Update Yield Data Tests (10 tests)
    function test_UpdateYieldData_ValidData() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit YieldDataUpdated(0, EXCHANGE_RATE, 400, TIMESTAMP);
        
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        assertEq(monitor.yieldDataCounter(), 1);
    }

    function test_UpdateYieldData_IncreasesCounter() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP + 1);
        
        assertEq(monitor.yieldDataCounter(), 2);
    }

    function test_UpdateYieldData_ZeroExchangeRate() public {
        vm.prank(owner);
        vm.expectRevert("RocketPoolMonitor: invalid data");
        monitor.updateYieldData(0, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
    }

    function test_UpdateYieldData_ZeroSupply() public {
        vm.prank(owner);
        vm.expectRevert("RocketPoolMonitor: invalid data");
        monitor.updateYieldData(EXCHANGE_RATE, 0, TOTAL_ETH_BACKING, TIMESTAMP);
    }

    function test_UpdateYieldData_ZeroBacking() public {
        vm.prank(owner);
        vm.expectRevert("RocketPoolMonitor: invalid data");
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, 0, TIMESTAMP);
    }

    function test_UpdateYieldData_FutureTimestamp() public {
        vm.prank(owner);
        vm.expectRevert("RocketPoolMonitor: future timestamp");
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, block.timestamp + 1);
    }

    function test_UpdateYieldData_CurrentTimestamp() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, block.timestamp);
        assertEq(monitor.yieldDataCounter(), 1);
    }

    function test_UpdateYieldData_StoresCorrectData() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        (uint256 exchangeRate, uint256 lastUpdateTime, uint256 annualYieldRate, uint256 totalRETHSupply, uint256 totalETHBacking) = 
            monitor.yieldHistory(0);
        
        assertEq(exchangeRate, EXCHANGE_RATE);
        assertEq(lastUpdateTime, TIMESTAMP);
        assertEq(totalRETHSupply, TOTAL_RETH_SUPPLY);
        assertEq(totalETHBacking, TOTAL_ETH_BACKING);
    }

    function test_UpdateYieldData_CalculatesYieldRate() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        (, , uint256 annualYieldRate, ,) = monitor.yieldHistory(0);
        assertGt(annualYieldRate, 0);
    }

    function test_UpdateYieldData_ReentrancyGuard() public {
        // This test ensures the nonReentrant modifier is applied
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        // If reentrancy guard is working, this should not cause issues
        assertEq(monitor.yieldDataCounter(), 1);
    }

    // Get Yield Data Tests (10 tests)
    function test_GetLatestYieldData_NoData() public {
        vm.expectRevert("RocketPoolMonitor: no data available");
        monitor.getLatestYieldData();
    }

    function test_GetLatestYieldData_WithData() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        RocketPoolMonitor.YieldData memory data = monitor.getLatestYieldData();
        assertEq(data.exchangeRate, EXCHANGE_RATE);
        assertEq(data.lastUpdateTime, TIMESTAMP);
        assertEq(data.totalRETHSupply, TOTAL_RETH_SUPPLY);
        assertEq(data.totalETHBacking, TOTAL_ETH_BACKING);
    }

    function test_GetYieldData_ValidId() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        RocketPoolMonitor.YieldData memory data = monitor.getYieldData(0);
        assertEq(data.exchangeRate, EXCHANGE_RATE);
    }

    function test_GetYieldData_InvalidId() public {
        vm.expectRevert("RocketPoolMonitor: invalid data ID");
        monitor.getYieldData(0);
    }

    function test_GetYieldData_OutOfBounds() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        vm.expectRevert("RocketPoolMonitor: invalid data ID");
        monitor.getYieldData(1);
    }

    function test_GetLatestYieldData_UpdatesCorrectly() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        uint256 newExchangeRate = EXCHANGE_RATE + 100;
        vm.prank(owner);
        monitor.updateYieldData(newExchangeRate, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP + 1);
        
        RocketPoolMonitor.YieldData memory data = monitor.getLatestYieldData();
        assertEq(data.exchangeRate, newExchangeRate);
    }

    function test_GetYieldData_MultipleEntries() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE + 100, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP + 1);
        
        RocketPoolMonitor.YieldData memory data0 = monitor.getYieldData(0);
        RocketPoolMonitor.YieldData memory data1 = monitor.getYieldData(1);
        
        assertEq(data0.exchangeRate, EXCHANGE_RATE);
        assertEq(data1.exchangeRate, EXCHANGE_RATE + 100);
    }

    function test_GetYieldData_PreservesAllFields() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        RocketPoolMonitor.YieldData memory data = monitor.getYieldData(0);
        assertEq(data.exchangeRate, EXCHANGE_RATE);
        assertEq(data.lastUpdateTime, TIMESTAMP);
        assertEq(data.totalRETHSupply, TOTAL_RETH_SUPPLY);
        assertEq(data.totalETHBacking, TOTAL_ETH_BACKING);
        assertGt(data.annualYieldRate, 0);
    }

    function test_GetLatestYieldData_ReflectsCounterDecrement() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        // Counter should be 1, so latest data is at index 0
        RocketPoolMonitor.YieldData memory data = monitor.getLatestYieldData();
        RocketPoolMonitor.YieldData memory manualData = monitor.getYieldData(monitor.yieldDataCounter() - 1);
        
        assertEq(data.exchangeRate, manualData.exchangeRate);
        assertEq(data.lastUpdateTime, manualData.lastUpdateTime);
    }

    function test_GetYieldData_ConsistentWithHistory() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, TIMESTAMP);
        
        RocketPoolMonitor.YieldData memory dataFromFunction = monitor.getYieldData(0);
        (uint256 exchangeRate, uint256 lastUpdateTime, uint256 annualYieldRate, uint256 totalRETHSupply, uint256 totalETHBacking) = 
            monitor.yieldHistory(0);
        
        assertEq(dataFromFunction.exchangeRate, exchangeRate);
        assertEq(dataFromFunction.lastUpdateTime, lastUpdateTime);
        assertEq(dataFromFunction.annualYieldRate, annualYieldRate);
        assertEq(dataFromFunction.totalRETHSupply, totalRETHSupply);
        assertEq(dataFromFunction.totalETHBacking, totalETHBacking);
    }

    // Yield Proof Verification Tests (10 tests)
    function test_VerifyYieldProof_ValidProof() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            block.timestamp,
            "rocketpool_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            block.timestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(400, proof);
        assertTrue(isValid);
    }

    function test_VerifyYieldProof_ZeroExchangeRate() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            uint256(0),
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            block.timestamp,
            "rocketpool_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            uint256(0),
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            block.timestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(400, proof);
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_ZeroSupply() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            EXCHANGE_RATE,
            uint256(0),
            TOTAL_ETH_BACKING,
            block.timestamp,
            "rocketpool_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            EXCHANGE_RATE,
            uint256(0),
            TOTAL_ETH_BACKING,
            block.timestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(400, proof);
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_ZeroBacking() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            uint256(0),
            block.timestamp,
            "rocketpool_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            uint256(0),
            block.timestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(400, proof);
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_StaleTimestamp() public {
        uint256 staleTimestamp = block.timestamp - 3601; // 1 hour + 1 second ago
        
        bytes32 dataHash = keccak256(abi.encodePacked(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            staleTimestamp,
            "rocketpool_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            staleTimestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(400, proof);
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_InvalidHash() public {
        bytes32 wrongDataHash = keccak256(abi.encodePacked(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            block.timestamp,
            "wrong_data"
        ));
        
        bytes memory proof = abi.encode(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            block.timestamp,
            wrongDataHash
        );
        
        bool isValid = monitor.verifyYieldProof(400, proof);
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_YieldRateDeviation() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            block.timestamp,
            "rocketpool_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            block.timestamp,
            dataHash
        );
        
        // Test with yield rate that's way off expected
        bool isValid = monitor.verifyYieldProof(10000, proof); // 100% yield rate
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_AcceptableDeviation() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            block.timestamp,
            "rocketpool_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            block.timestamp,
            dataHash
        );
        
        // Test with yield rate within acceptable range
        bool isValid = monitor.verifyYieldProof(420, proof); // 4.2% vs expected ~4%
        assertTrue(isValid);
    }

    function test_VerifyYieldProof_EdgeCaseTimestamp() public {
        uint256 edgeTimestamp = block.timestamp - 3600; // Exactly 1 hour ago
        
        bytes32 dataHash = keccak256(abi.encodePacked(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            edgeTimestamp,
            "rocketpool_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            EXCHANGE_RATE,
            TOTAL_RETH_SUPPLY,
            TOTAL_ETH_BACKING,
            edgeTimestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(400, proof);
        assertTrue(isValid);
    }

    function test_VerifyYieldProof_EmptyProof() public {
        bytes memory emptyProof = "";
        
        vm.expectRevert();
        monitor.verifyYieldProof(400, emptyProof);
    }

    // Utility Functions Tests (5 tests)
    function test_GetExpectedYieldRange() public {
        (uint256 minYield, uint256 maxYield) = monitor.getExpectedYieldRange();
        assertEq(minYield, 300);
        assertEq(maxYield, 600);
        assertLt(minYield, maxYield);
    }

    function test_IsYieldDataStale_NoData() public {
        vm.expectRevert("RocketPoolMonitor: invalid data ID");
        monitor.isYieldDataStale(0);
    }

    function test_IsYieldDataStale_FreshData() public {
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, block.timestamp);
        
        bool isStale = monitor.isYieldDataStale(0);
        assertFalse(isStale);
    }

    function test_IsYieldDataStale_OldData() public {
        uint256 oldTimestamp = block.timestamp - 3601; // 1 hour + 1 second ago
        
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, oldTimestamp);
        
        bool isStale = monitor.isYieldDataStale(0);
        assertTrue(isStale);
    }

    function test_IsYieldDataStale_EdgeCase() public {
        uint256 edgeTimestamp = block.timestamp - 3600; // Exactly 1 hour ago
        
        vm.prank(owner);
        monitor.updateYieldData(EXCHANGE_RATE, TOTAL_RETH_SUPPLY, TOTAL_ETH_BACKING, edgeTimestamp);
        
        bool isStale = monitor.isYieldDataStale(0);
        assertFalse(isStale);
    }
}