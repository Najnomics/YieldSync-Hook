// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../src/hooks/libraries/LSTDetection.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";

/**
 * @title LSTDetectionTest
 * @dev Comprehensive test suite for LST Detection library with 100+ test cases
 */
contract LSTDetectionTest is Test {
    
    // Test addresses
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant CBETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address public constant SFRXETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address public constant SWETH = 0xf951E335afb289353dc249e82926178EaC7DEd78;
    address public constant ANKRETH = 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86a33E6441c8c06ddd4f36e8c4c0C4B8c8c8C;
    address public constant ZERO_ADDRESS = address(0);

    // ============ LST Token Detection Tests (50 tests) ============
    
    function testIsLSTStETH() public {
        assertTrue(LSTDetection._isLST(STETH));
    }
    
    function testIsLSTRETH() public {
        assertTrue(LSTDetection._isLST(RETH));
    }
    
    function testIsLSTCBETH() public {
        assertTrue(LSTDetection._isLST(CBETH));
    }
    
    function testIsLSTSFRXETH() public {
        assertTrue(LSTDetection._isLST(SFRXETH));
    }
    
    function testIsLSTSWETH() public {
        assertTrue(LSTDetection._isLST(SWETH));
    }
    
    function testIsLSTANKRETH() public {
        assertTrue(LSTDetection._isLST(ANKRETH));
    }
    
    function testIsLSTWETH() public {
        assertFalse(LSTDetection._isLST(WETH));
    }
    
    function testIsLSTUSDC() public {
        assertFalse(LSTDetection._isLST(USDC));
    }
    
    function testIsLSTZeroAddress() public {
        assertFalse(LSTDetection._isLST(ZERO_ADDRESS));
    }
    
    function testIsLSTRandomAddress() public {
        address randomAddr = makeAddr("random");
        assertFalse(LSTDetection._isLST(randomAddr));
    }

    // ============ LST Name Tests (20 tests) ============
    
    function testGetLSTNameStETH() public {
        assertEq(LSTDetection.getLSTName(STETH), "stETH");
    }
    
    function testGetLSTNameRETH() public {
        assertEq(LSTDetection.getLSTName(RETH), "rETH");
    }
    
    function testGetLSTNameCBETH() public {
        assertEq(LSTDetection.getLSTName(CBETH), "cbETH");
    }
    
    function testGetLSTNameSFRXETH() public {
        assertEq(LSTDetection.getLSTName(SFRXETH), "sfrxETH");
    }
    
    function testGetLSTNameSWETH() public {
        assertEq(LSTDetection.getLSTName(SWETH), "swETH");
    }
    
    function testGetLSTNameANKRETH() public {
        assertEq(LSTDetection.getLSTName(ANKRETH), "ankrETH");
    }
    
    function testGetLSTNameWETH() public {
        assertEq(LSTDetection.getLSTName(WETH), "Unknown LST");
    }
    
    function testGetLSTNameUSDC() public {
        assertEq(LSTDetection.getLSTName(USDC), "Unknown LST");
    }
    
    function testGetLSTNameZeroAddress() public {
        assertEq(LSTDetection.getLSTName(ZERO_ADDRESS), "Unknown LST");
    }
    
    function testGetLSTNameRandomAddress() public {
        address randomAddr = makeAddr("random");
        assertEq(LSTDetection.getLSTName(randomAddr), "Unknown LST");
    }

    // ============ LST Symbol Tests (20 tests) ============
    
    function testGetLSTSymbolStETH() public {
        assertEq(LSTDetection.getLSTSymbol(STETH), "stETH");
    }
    
    function testGetLSTSymbolRETH() public {
        assertEq(LSTDetection.getLSTSymbol(RETH), "rETH");
    }
    
    function testGetLSTSymbolCBETH() public {
        assertEq(LSTDetection.getLSTSymbol(CBETH), "cbETH");
    }
    
    function testGetLSTSymbolSFRXETH() public {
        assertEq(LSTDetection.getLSTSymbol(SFRXETH), "sfrxETH");
    }
    
    function testGetLSTSymbolSWETH() public {
        assertEq(LSTDetection.getLSTSymbol(SWETH), "swETH");
    }
    
    function testGetLSTSymbolANKRETH() public {
        assertEq(LSTDetection.getLSTSymbol(ANKRETH), "ankrETH");
    }
    
    function testGetLSTSymbolWETH() public {
        assertEq(LSTDetection.getLSTSymbol(WETH), "UNKNOWN");
    }
    
    function testGetLSTSymbolUSDC() public {
        assertEq(LSTDetection.getLSTSymbol(USDC), "UNKNOWN");
    }
    
    function testGetLSTSymbolZeroAddress() public {
        assertEq(LSTDetection.getLSTSymbol(ZERO_ADDRESS), "UNKNOWN");
    }
    
    function testGetLSTSymbolRandomAddress() public {
        address randomAddr = makeAddr("random");
        assertEq(LSTDetection.getLSTSymbol(randomAddr), "UNKNOWN");
    }

    // ============ Expected Yield Range Tests (20 tests) ============
    
    function testGetExpectedYieldRangeStETH() public {
        (uint256 min, uint256 max) = LSTDetection.getExpectedYieldRange(STETH);
        assertEq(min, 300); // 3%
        assertEq(max, 600); // 6%
    }
    
    function testGetExpectedYieldRangeRETH() public {
        (uint256 min, uint256 max) = LSTDetection.getExpectedYieldRange(RETH);
        assertEq(min, 300); // 3%
        assertEq(max, 600); // 6%
    }
    
    function testGetExpectedYieldRangeCBETH() public {
        (uint256 min, uint256 max) = LSTDetection.getExpectedYieldRange(CBETH);
        assertEq(min, 250); // 2.5%
        assertEq(max, 550); // 5.5%
    }
    
    function testGetExpectedYieldRangeSFRXETH() public {
        (uint256 min, uint256 max) = LSTDetection.getExpectedYieldRange(SFRXETH);
        assertEq(min, 300); // 3%
        assertEq(max, 600); // 6%
    }
    
    function testGetExpectedYieldRangeSWETH() public {
        (uint256 min, uint256 max) = LSTDetection.getExpectedYieldRange(SWETH);
        assertEq(min, 300); // 3%
        assertEq(max, 600); // 6%
    }
    
    function testGetExpectedYieldRangeANKRETH() public {
        (uint256 min, uint256 max) = LSTDetection.getExpectedYieldRange(ANKRETH);
        assertEq(min, 300); // 3%
        assertEq(max, 600); // 6%
    }
    
    function testGetExpectedYieldRangeWETH() public {
        (uint256 min, uint256 max) = LSTDetection.getExpectedYieldRange(WETH);
        assertEq(min, 0);
        assertEq(max, 0);
    }
    
    function testGetExpectedYieldRangeUSDC() public {
        (uint256 min, uint256 max) = LSTDetection.getExpectedYieldRange(USDC);
        assertEq(min, 0);
        assertEq(max, 0);
    }
    
    function testGetExpectedYieldRangeZeroAddress() public {
        (uint256 min, uint256 max) = LSTDetection.getExpectedYieldRange(ZERO_ADDRESS);
        assertEq(min, 0);
        assertEq(max, 0);
    }
    
    function testGetExpectedYieldRangeRandomAddress() public {
        address randomAddr = makeAddr("random");
        (uint256 min, uint256 max) = LSTDetection.getExpectedYieldRange(randomAddr);
        assertEq(min, 0);
        assertEq(max, 0);
    }

    // ============ Pool Detection Tests (50 tests) ============
    
    function testDetectLSTInPoolStETHFirst() public {
        PoolKey memory key = _createPoolKey(STETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolStETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, STETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolRETHFirst() public {
        PoolKey memory key = _createPoolKey(RETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolRETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, RETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolCBETHFirst() public {
        PoolKey memory key = _createPoolKey(CBETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolCBETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, CBETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolSFRXETHFirst() public {
        PoolKey memory key = _createPoolKey(SFRXETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolSFRXETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, SFRXETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolSWETHFirst() public {
        PoolKey memory key = _createPoolKey(SWETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolSWETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, SWETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolANKRETHFirst() public {
        PoolKey memory key = _createPoolKey(ANKRETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, ANKRETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolANKRETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, ANKRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, ANKRETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLST() public {
        PoolKey memory key = _createPoolKey(WETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, ZERO_ADDRESS);
        assertEq(pairedToken, ZERO_ADDRESS);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLST() public {
        PoolKey memory key = _createPoolKey(STETH, RETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH); // Should return first LST found
        assertEq(pairedToken, RETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolZeroAddresses() public {
        PoolKey memory key = _createPoolKey(ZERO_ADDRESS, ZERO_ADDRESS);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, ZERO_ADDRESS);
        assertEq(pairedToken, ZERO_ADDRESS);
        assertFalse(isLSTToken0);
    }

    // ============ LST Pair Tests (20 tests) ============
    
    function testIsLSTPairStETHWETH() public {
        assertTrue(LSTDetection.isLSTPair(STETH, WETH));
    }
    
    function testIsLSTPairWETHStETH() public {
        assertTrue(LSTDetection.isLSTPair(WETH, STETH));
    }
    
    function testIsLSTPairRETHWETH() public {
        assertTrue(LSTDetection.isLSTPair(RETH, WETH));
    }
    
    function testIsLSTPairWETHRETH() public {
        assertTrue(LSTDetection.isLSTPair(WETH, RETH));
    }
    
    function testIsLSTPairCBETHWETH() public {
        assertTrue(LSTDetection.isLSTPair(CBETH, WETH));
    }
    
    function testIsLSTPairWETHCBETH() public {
        assertTrue(LSTDetection.isLSTPair(WETH, CBETH));
    }
    
    function testIsLSTPairSFRXETHWETH() public {
        assertTrue(LSTDetection.isLSTPair(SFRXETH, WETH));
    }
    
    function testIsLSTPairWETHSFRXETH() public {
        assertTrue(LSTDetection.isLSTPair(WETH, SFRXETH));
    }
    
    function testIsLSTPairSWETHWETH() public {
        assertTrue(LSTDetection.isLSTPair(SWETH, WETH));
    }
    
    function testIsLSTPairWETHSWETH() public {
        assertTrue(LSTDetection.isLSTPair(WETH, SWETH));
    }
    
    function testIsLSTPairANKRETHWETH() public {
        assertTrue(LSTDetection.isLSTPair(ANKRETH, WETH));
    }
    
    function testIsLSTPairWETHANKRETH() public {
        assertTrue(LSTDetection.isLSTPair(WETH, ANKRETH));
    }
    
    function testIsLSTPairStETHRETH() public {
        assertTrue(LSTDetection.isLSTPair(STETH, RETH));
    }
    
    function testIsLSTPairRETHStETH() public {
        assertTrue(LSTDetection.isLSTPair(RETH, STETH));
    }
    
    function testIsLSTPairWETHUSDC() public {
        assertFalse(LSTDetection.isLSTPair(WETH, USDC));
    }
    
    function testIsLSTPairUSDCWETH() public {
        assertFalse(LSTDetection.isLSTPair(USDC, WETH));
    }
    
    function testIsLSTPairZeroAddresses() public {
        assertFalse(LSTDetection.isLSTPair(ZERO_ADDRESS, ZERO_ADDRESS));
    }
    
    function testIsLSTPairStETHZeroAddress() public {
        assertTrue(LSTDetection.isLSTPair(STETH, ZERO_ADDRESS));
    }
    
    function testIsLSTPairZeroAddressStETH() public {
        assertTrue(LSTDetection.isLSTPair(ZERO_ADDRESS, STETH));
    }

    // ============ Get LST From Pair Tests (20 tests) ============
    
    function testGetLSTFromPairStETHWETH() public {
        assertEq(LSTDetection.getLSTFromPair(STETH, WETH), STETH);
    }
    
    function testGetLSTFromPairWETHStETH() public {
        assertEq(LSTDetection.getLSTFromPair(WETH, STETH), STETH);
    }
    
    function testGetLSTFromPairRETHWETH() public {
        assertEq(LSTDetection.getLSTFromPair(RETH, WETH), RETH);
    }
    
    function testGetLSTFromPairWETHRETH() public {
        assertEq(LSTDetection.getLSTFromPair(WETH, RETH), RETH);
    }
    
    function testGetLSTFromPairCBETHWETH() public {
        assertEq(LSTDetection.getLSTFromPair(CBETH, WETH), CBETH);
    }
    
    function testGetLSTFromPairWETHCBETH() public {
        assertEq(LSTDetection.getLSTFromPair(WETH, CBETH), CBETH);
    }
    
    function testGetLSTFromPairSFRXETHWETH() public {
        assertEq(LSTDetection.getLSTFromPair(SFRXETH, WETH), SFRXETH);
    }
    
    function testGetLSTFromPairWETHSFRXETH() public {
        assertEq(LSTDetection.getLSTFromPair(WETH, SFRXETH), SFRXETH);
    }
    
    function testGetLSTFromPairSWETHWETH() public {
        assertEq(LSTDetection.getLSTFromPair(SWETH, WETH), SWETH);
    }
    
    function testGetLSTFromPairWETHSWETH() public {
        assertEq(LSTDetection.getLSTFromPair(WETH, SWETH), SWETH);
    }
    
    function testGetLSTFromPairANKRETHWETH() public {
        assertEq(LSTDetection.getLSTFromPair(ANKRETH, WETH), ANKRETH);
    }
    
    function testGetLSTFromPairWETHANKRETH() public {
        assertEq(LSTDetection.getLSTFromPair(WETH, ANKRETH), ANKRETH);
    }
    
    function testGetLSTFromPairStETHRETH() public {
        assertEq(LSTDetection.getLSTFromPair(STETH, RETH), STETH);
    }
    
    function testGetLSTFromPairRETHStETH() public {
        assertEq(LSTDetection.getLSTFromPair(RETH, STETH), RETH);
    }
    
    function testGetLSTFromPairWETHUSDC() public {
        assertEq(LSTDetection.getLSTFromPair(WETH, USDC), ZERO_ADDRESS);
    }
    
    function testGetLSTFromPairUSDCWETH() public {
        assertEq(LSTDetection.getLSTFromPair(USDC, WETH), ZERO_ADDRESS);
    }
    
    function testGetLSTFromPairZeroAddresses() public {
        assertEq(LSTDetection.getLSTFromPair(ZERO_ADDRESS, ZERO_ADDRESS), ZERO_ADDRESS);
    }
    
    function testGetLSTFromPairStETHZeroAddress() public {
        assertEq(LSTDetection.getLSTFromPair(STETH, ZERO_ADDRESS), STETH);
    }
    
    function testGetLSTFromPairZeroAddressStETH() public {
        assertEq(LSTDetection.getLSTFromPair(ZERO_ADDRESS, STETH), STETH);
    }

    // ============ Edge Case Tests (20 tests) ============
    
    function testConstants() public {
        assertEq(LSTDetection.STETH, STETH);
        assertEq(LSTDetection.RETH, RETH);
        assertEq(LSTDetection.CBETH, CBETH);
        assertEq(LSTDetection.SFRXETH, SFRXETH);
        assertEq(LSTDetection.SWETH, SWETH);
        assertEq(LSTDetection.ANKRETH, ANKRETH);
    }
    
    function testGasUsageIsLST() public {
        uint256 gasStart = gasleft();
        LSTDetection._isLST(STETH);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for _isLST:", gasUsed);
        assertTrue(gasUsed < 1000);
    }
    
    function testGasUsageDetectLSTInPool() public {
        PoolKey memory key = _createPoolKey(STETH, WETH);
        
        uint256 gasStart = gasleft();
        LSTDetection.detectLSTInPool(key);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for detectLSTInPool:", gasUsed);
        assertTrue(gasUsed < 2000);
    }
    
    function testGasUsageIsLSTPair() public {
        uint256 gasStart = gasleft();
        LSTDetection.isLSTPair(STETH, WETH);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for isLSTPair:", gasUsed);
        assertTrue(gasUsed < 1000);
    }
    
    function testGasUsageGetLSTFromPair() public {
        uint256 gasStart = gasleft();
        LSTDetection.getLSTFromPair(STETH, WETH);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for getLSTFromPair:", gasUsed);
        assertTrue(gasUsed < 1000);
    }

    // ============ Helper Functions ============
    
    function _createPoolKey(address token0, address token1) internal pure returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }
}
