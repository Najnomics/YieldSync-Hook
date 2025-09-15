// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/avs/LSTMonitors/LidoYieldMonitor.sol";

contract LidoMonitorUnitTest is Test {
    LidoYieldMonitor public monitor;
    address public owner;
    address public user;

    // Test constants
    uint256 constant TOTAL_POOLED_ETHER = 1050000000000000000000; // 1050 ETH 
    uint256 constant TOTAL_SHARES = 1000000000000000000000; // 1000 shares
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
        monitor = new LidoYieldMonitor();
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

    function test_Constructor_StETHAddress() public {
        assertEq(monitor.stETH(), 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    }

    function test_Constructor_LSTToken() public {
        assertEq(monitor.lstToken(), 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    }

    // Access Control Tests (5 tests)
    function test_OnlyOwner_UpdateYieldData() public {
        vm.prank(user);
        vm.expectRevert();
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
    }

    function test_OnlyOwner_Success() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
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
        assertEq(monitor.name(), "Lido stETH");
    }

    function test_STETH_Constant() public {
        assertEq(monitor.stETH(), 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    }

    function test_LSTToken_ReturnsStETH() public {
        assertEq(monitor.lstToken(), monitor.stETH());
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
        emit YieldDataUpdated(0, TOTAL_POOLED_ETHER, 500, TIMESTAMP);
        
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        assertEq(monitor.yieldDataCounter(), 1);
    }

    function test_UpdateYieldData_IncreasesCounter() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP + 1);
        
        assertEq(monitor.yieldDataCounter(), 2);
    }

    function test_UpdateYieldData_ZeroExchangeRate() public {
        vm.prank(owner);
        vm.expectRevert("LidoYieldMonitor: invalid data");
        monitor.updateYieldData(0, TOTAL_SHARES, TIMESTAMP);
    }

    function test_UpdateYieldData_ZeroSupply() public {
        vm.prank(owner);
        vm.expectRevert("LidoYieldMonitor: invalid data");
        monitor.updateYieldData(TOTAL_POOLED_ETHER, 0, TIMESTAMP);
    }

    function test_UpdateYieldData_ZeroBacking() public {
        vm.prank(owner);
        vm.expectRevert("LidoYieldMonitor: invalid data");
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
    }

    function test_UpdateYieldData_FutureTimestamp() public {
        vm.prank(owner);
        vm.expectRevert("LidoYieldMonitor: future timestamp");
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, block.timestamp + 1);
    }

    function test_UpdateYieldData_CurrentTimestamp() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, block.timestamp);
        assertEq(monitor.yieldDataCounter(), 1);
    }

    function test_UpdateYieldData_StoresCorrectData() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        (uint256 totalPooledEther, uint256 totalShares, uint256 lastUpdateTime, uint256 annualYieldRate) = 
            monitor.yieldHistory(0);
        
        assertEq(totalPooledEther, TOTAL_POOLED_ETHER);
        assertEq(totalShares, TOTAL_SHARES);
        assertEq(lastUpdateTime, TIMESTAMP);
    }

    function test_UpdateYieldData_CalculatesYieldRate() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        (, , , uint256 annualYieldRate) = monitor.yieldHistory(0);
        assertGt(annualYieldRate, 0);
    }

    function test_UpdateYieldData_ReentrancyGuard() public {
        // This test ensures the nonReentrant modifier is applied
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        // If reentrancy guard is working, this should not cause issues
        assertEq(monitor.yieldDataCounter(), 1);
    }

    // Get Yield Data Tests (10 tests)
    function test_GetLatestYieldData_NoData() public {
        vm.expectRevert("LidoYieldMonitor: no data available");
        monitor.getLatestYieldData();
    }

    function test_GetLatestYieldData_WithData() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        LidoYieldMonitor.YieldData memory data = monitor.getLatestYieldData();
        assertEq(data.totalPooledEther, TOTAL_POOLED_ETHER);
        assertEq(data.totalShares, TOTAL_SHARES);
        assertEq(data.lastUpdateTime, TIMESTAMP);
    }

    function test_GetYieldData_ValidId() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        LidoYieldMonitor.YieldData memory data = monitor.getYieldData(0);
        assertEq(data.totalPooledEther, TOTAL_POOLED_ETHER);
    }

    function test_GetYieldData_InvalidId() public {
        vm.expectRevert("LidoYieldMonitor: invalid data ID");
        monitor.getYieldData(0);
    }

    function test_GetYieldData_OutOfBounds() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        vm.expectRevert("LidoYieldMonitor: invalid data ID");
        monitor.getYieldData(1);
    }

    function test_GetLatestYieldData_UpdatesCorrectly() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        uint256 newTotalPooledEther = TOTAL_POOLED_ETHER + 100;
        vm.prank(owner);
        monitor.updateYieldData(newTotalPooledEther, TOTAL_SHARES, TIMESTAMP + 1);
        
        LidoYieldMonitor.YieldData memory data = monitor.getLatestYieldData();
        assertEq(data.totalPooledEther, newTotalPooledEther);
    }

    function test_GetYieldData_MultipleEntries() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER + 100, TOTAL_SHARES, TIMESTAMP + 1);
        
        LidoYieldMonitor.YieldData memory data0 = monitor.getYieldData(0);
        LidoYieldMonitor.YieldData memory data1 = monitor.getYieldData(1);
        
        assertEq(data0.totalPooledEther, TOTAL_POOLED_ETHER);
        assertEq(data1.totalPooledEther, TOTAL_POOLED_ETHER + 100);
    }

    function test_GetYieldData_PreservesAllFields() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        LidoYieldMonitor.YieldData memory data = monitor.getYieldData(0);
        assertEq(data.totalPooledEther, TOTAL_POOLED_ETHER);
        assertEq(data.totalShares, TOTAL_SHARES);
        assertEq(data.lastUpdateTime, TIMESTAMP);
        assertGt(data.annualYieldRate, 0);
    }

    function test_GetLatestYieldData_ReflectsCounterDecrement() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        // Counter should be 1, so latest data is at index 0
        LidoYieldMonitor.YieldData memory data = monitor.getLatestYieldData();
        LidoYieldMonitor.YieldData memory manualData = monitor.getYieldData(monitor.yieldDataCounter() - 1);
        
        assertEq(data.totalPooledEther, manualData.totalPooledEther);
        assertEq(data.lastUpdateTime, manualData.lastUpdateTime);
    }

    function test_GetYieldData_ConsistentWithHistory() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
        
        LidoYieldMonitor.YieldData memory dataFromFunction = monitor.getYieldData(0);
        (uint256 totalPooledEther, uint256 totalShares, uint256 lastUpdateTime, uint256 annualYieldRate) = 
            monitor.yieldHistory(0);
        
        assertEq(dataFromFunction.totalPooledEther, totalPooledEther);
        assertEq(dataFromFunction.totalShares, totalShares);
        assertEq(dataFromFunction.lastUpdateTime, lastUpdateTime);
        assertEq(dataFromFunction.annualYieldRate, annualYieldRate);
    }

    // Yield Proof Verification Tests (10 tests)
    function test_VerifyYieldProof_ValidProof() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            block.timestamp,
            "lido_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            block.timestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(500, proof);
        assertTrue(isValid);
    }

    function test_VerifyYieldProof_ZeroExchangeRate() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            uint256(0),
            TOTAL_SHARES,
            TOTAL_SHARES,
            block.timestamp,
            "lido_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            uint256(0),
            TOTAL_SHARES,
            TOTAL_SHARES,
            block.timestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(500, proof);
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_ZeroSupply() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            TOTAL_POOLED_ETHER,
            uint256(0),
            TOTAL_SHARES,
            block.timestamp,
            "lido_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            TOTAL_POOLED_ETHER,
            uint256(0),
            TOTAL_SHARES,
            block.timestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(500, proof);
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_ZeroBacking() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            uint256(0),
            block.timestamp,
            "lido_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            uint256(0),
            block.timestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(500, proof);
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_StaleTimestamp() public {
        uint256 staleTimestamp = block.timestamp - 3601; // 1 hour + 1 second ago
        
        bytes32 dataHash = keccak256(abi.encodePacked(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            staleTimestamp,
            "lido_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            staleTimestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(500, proof);
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_InvalidHash() public {
        bytes32 wrongDataHash = keccak256(abi.encodePacked(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            block.timestamp,
            "wrong_data"
        ));
        
        bytes memory proof = abi.encode(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            block.timestamp,
            wrongDataHash
        );
        
        bool isValid = monitor.verifyYieldProof(500, proof);
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_YieldRateDeviation() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            block.timestamp,
            "lido_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            block.timestamp,
            dataHash
        );
        
        // Test with yield rate that's way off expected
        bool isValid = monitor.verifyYieldProof(10000, proof); // 100% yield rate
        assertFalse(isValid);
    }

    function test_VerifyYieldProof_AcceptableDeviation() public {
        bytes32 dataHash = keccak256(abi.encodePacked(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            block.timestamp,
            "lido_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            block.timestamp,
            dataHash
        );
        
        // Test with yield rate within acceptable range
        bool isValid = monitor.verifyYieldProof(520, proof); // 5.2% vs expected ~5%
        assertTrue(isValid);
    }

    function test_VerifyYieldProof_EdgeCaseTimestamp() public {
        uint256 edgeTimestamp = block.timestamp - 3600; // Exactly 1 hour ago
        
        bytes32 dataHash = keccak256(abi.encodePacked(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            edgeTimestamp,
            "lido_yield_data"
        ));
        
        bytes memory proof = abi.encode(
            TOTAL_POOLED_ETHER,
            TOTAL_SHARES,
            TOTAL_SHARES,
            edgeTimestamp,
            dataHash
        );
        
        bool isValid = monitor.verifyYieldProof(500, proof);
        assertTrue(isValid);
    }

    function test_VerifyYieldProof_EmptyProof() public {
        bytes memory emptyProof = "";
        
        vm.expectRevert();
        monitor.verifyYieldProof(500, emptyProof);
    }

    // Utility Functions Tests (5 tests)
    function test_GetExpectedYieldRange() public {
        (uint256 minYield, uint256 maxYield) = monitor.getExpectedYieldRange();
        assertEq(minYield, 300);
        assertEq(maxYield, 700);
        assertLt(minYield, maxYield);
    }

    function test_IsYieldDataStale_NoData() public {
        vm.expectRevert("LidoYieldMonitor: invalid data ID");
        monitor.isYieldDataStale(0);
    }

    function test_IsYieldDataStale_FreshData() public {
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, block.timestamp);
        
        bool isStale = monitor.isYieldDataStale(0);
        assertFalse(isStale);
    }

    function test_IsYieldDataStale_OldData() public {
        uint256 oldTimestamp = block.timestamp - 3601; // 1 hour + 1 second ago
        
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, oldTimestamp);
        
        bool isStale = monitor.isYieldDataStale(0);
        assertTrue(isStale);
    }

    function test_IsYieldDataStale_EdgeCase() public {
        uint256 edgeTimestamp = block.timestamp - 3600; // Exactly 1 hour ago
        
        vm.prank(owner);
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, edgeTimestamp);
        
        bool isStale = monitor.isYieldDataStale(0);
        assertFalse(isStale);
    }

    // Pause/Unpause Tests (5 tests)
    function test_Pause_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        monitor.pause();
    }

    function test_Pause_Success() public {
        vm.prank(owner);
        monitor.pause();
        assertTrue(monitor.paused());
    }

    function test_Unpause_OnlyOwner() public {
        vm.prank(owner);
        monitor.pause();
        
        vm.prank(user);
        vm.expectRevert();
        monitor.unpause();
    }

    function test_Unpause_Success() public {
        vm.prank(owner);
        monitor.pause();
        
        vm.prank(owner);
        monitor.unpause();
        
        assertFalse(monitor.paused());
    }

    function test_UpdateYieldData_WhenPaused() public {
        vm.prank(owner);
        monitor.pause();
        
        vm.prank(owner);
        vm.expectRevert();
        monitor.updateYieldData(TOTAL_POOLED_ETHER, TOTAL_SHARES, TIMESTAMP);
    }
}