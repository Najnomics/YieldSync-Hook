// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/hooks/libraries/LSTDetection.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";

/**
 * @title LSTDetectionUnitTest
 * @dev Unit tests for LST Detection library - 50 focused unit tests
 */
contract LSTDetectionUnitTest is Test {
    
    // Known LST addresses from the library
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant CBETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address public constant SFRXETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address public constant SWETH = 0xf951E335afb289353dc249e82926178EaC7DEd78;
    address public constant ANKRETH = 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb;
    
    // Non-LST addresses
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86a33E6441c8c06ddd4f36e8c4c0C4B8c8c8C;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    
    function _createPoolKey(address token0, address token1) internal pure returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    // ============ Unit Tests for _isLST function (15 tests) ============
    
    function test_isLST_ReturnsTrue_ForStETH() public {
        assertTrue(LSTDetection._isLST(STETH));
    }
    
    function test_isLST_ReturnsTrue_ForRETH() public {
        assertTrue(LSTDetection._isLST(RETH));
    }
    
    function test_isLST_ReturnsTrue_ForCBETH() public {
        assertTrue(LSTDetection._isLST(CBETH));
    }
    
    function test_isLST_ReturnsTrue_ForSFRXETH() public {
        assertTrue(LSTDetection._isLST(SFRXETH));
    }
    
    function test_isLST_ReturnsTrue_ForSWETH() public {
        assertTrue(LSTDetection._isLST(SWETH));
    }
    
    function test_isLST_ReturnsTrue_ForANKRETH() public {
        assertTrue(LSTDetection._isLST(ANKRETH));
    }
    
    function test_isLST_ReturnsFalse_ForWETH() public {
        assertFalse(LSTDetection._isLST(WETH));
    }
    
    function test_isLST_ReturnsFalse_ForUSDC() public {
        assertFalse(LSTDetection._isLST(USDC));
    }
    
    function test_isLST_ReturnsFalse_ForDAI() public {
        assertFalse(LSTDetection._isLST(DAI));
    }
    
    function test_isLST_ReturnsFalse_ForZeroAddress() public {
        assertFalse(LSTDetection._isLST(address(0)));
    }
    
    function test_isLST_ReturnsFalse_ForContractAddress() public {
        assertFalse(LSTDetection._isLST(address(this)));
    }
    
    function test_isLST_ReturnsFalse_ForRandomAddress() public {
        assertFalse(LSTDetection._isLST(address(0x1234567890123456789012345678901234567890)));
    }
    
    function test_isLST_ReturnsFalse_ForMaxAddress() public {
        assertFalse(LSTDetection._isLST(address(type(uint160).max)));
    }
    
    function test_isLST_ReturnsFalse_ForMsgSender() public {
        assertFalse(LSTDetection._isLST(msg.sender));
    }
    
    function test_isLST_ReturnsFalse_ForLowValueAddress() public {
        assertFalse(LSTDetection._isLST(address(1)));
    }

    // ============ Unit Tests for detectLSTInPool - LST as Token0 (10 tests) ============
    
    function test_detectLSTInPool_DetectsStETH_AsToken0() public {
        PoolKey memory key = _createPoolKey(STETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function test_detectLSTInPool_DetectsRETH_AsToken0() public {
        PoolKey memory key = _createPoolKey(RETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, USDC);
        assertTrue(isLSTToken0);
    }
    
    function test_detectLSTInPool_DetectsCBETH_AsToken0() public {
        PoolKey memory key = _createPoolKey(CBETH, DAI);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, DAI);
        assertTrue(isLSTToken0);
    }
    
    function test_detectLSTInPool_DetectsSFRXETH_AsToken0() public {
        PoolKey memory key = _createPoolKey(SFRXETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function test_detectLSTInPool_DetectsSWETH_AsToken0() public {
        PoolKey memory key = _createPoolKey(SWETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, USDC);
        assertTrue(isLSTToken0);
    }
    
    function test_detectLSTInPool_DetectsANKRETH_AsToken0() public {
        PoolKey memory key = _createPoolKey(ANKRETH, DAI);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, ANKRETH);
        assertEq(pairedToken, DAI);
        assertTrue(isLSTToken0);
    }
    
    function test_detectLSTInPool_PrioritizesToken0_WhenBothAreLST() public {
        PoolKey memory key = _createPoolKey(STETH, RETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH); // Should return token0 when both are LST
        assertEq(pairedToken, RETH);
        assertTrue(isLSTToken0);
    }
    
    function test_detectLSTInPool_PrioritizesToken0_WithDifferentLSTs() public {
        PoolKey memory key = _createPoolKey(CBETH, SFRXETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH); // Should return token0 when both are LST
        assertEq(pairedToken, SFRXETH);
        assertTrue(isLSTToken0);
    }
    
    function test_detectLSTInPool_HandlesSameLST_InBothPositions() public {
        PoolKey memory key = _createPoolKey(STETH, STETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, STETH);
        assertTrue(isLSTToken0);
    }
    
    function test_detectLSTInPool_WorksWithAllLSTCombinations() public {
        PoolKey memory key = _createPoolKey(SWETH, ANKRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, ANKRETH);
        assertTrue(isLSTToken0);
    }

    // ============ Unit Tests for detectLSTInPool - LST as Token1 (10 tests) ============
    
    function test_detectLSTInPool_DetectsStETH_AsToken1() public {
        PoolKey memory key = _createPoolKey(WETH, STETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_DetectsRETH_AsToken1() public {
        PoolKey memory key = _createPoolKey(USDC, RETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, USDC);
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_DetectsCBETH_AsToken1() public {
        PoolKey memory key = _createPoolKey(DAI, CBETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, DAI);
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_DetectsSFRXETH_AsToken1() public {
        PoolKey memory key = _createPoolKey(WETH, SFRXETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_DetectsSWETH_AsToken1() public {
        PoolKey memory key = _createPoolKey(USDC, SWETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, USDC);
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_DetectsANKRETH_AsToken1() public {
        PoolKey memory key = _createPoolKey(DAI, ANKRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, ANKRETH);
        assertEq(pairedToken, DAI);
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_Token1Detection_WithMultiplePairs() public {
        // Test with WETH paired with multiple LSTs
        address[6] memory lsts = [STETH, RETH, CBETH, SFRXETH, SWETH, ANKRETH];
        
        for (uint i = 0; i < lsts.length; i++) {
            PoolKey memory key = _createPoolKey(WETH, lsts[i]);
            (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
                LSTDetection.detectLSTInPool(key);
            
            assertTrue(hasLST);
            assertEq(lstToken, lsts[i]);
            assertEq(pairedToken, WETH);
            assertFalse(isLSTToken0);
        }
    }
    
    function test_detectLSTInPool_Token1Detection_WithStablecoins() public {
        address[2] memory stablecoins = [USDC, DAI];
        
        for (uint i = 0; i < stablecoins.length; i++) {
            PoolKey memory key = _createPoolKey(stablecoins[i], STETH);
            (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
                LSTDetection.detectLSTInPool(key);
            
            assertTrue(hasLST);
            assertEq(lstToken, STETH);
            assertEq(pairedToken, stablecoins[i]);
            assertFalse(isLSTToken0);
        }
    }
    
    function test_detectLSTInPool_ConsistentBehavior_TokenOrderReversed() public {
        // Test same pair in both orders
        PoolKey memory key1 = _createPoolKey(STETH, WETH);
        PoolKey memory key2 = _createPoolKey(WETH, STETH);
        
        (bool hasLST1, address lstToken1, address pairedToken1, bool isLSTToken0_1) = 
            LSTDetection.detectLSTInPool(key1);
        (bool hasLST2, address lstToken2, address pairedToken2, bool isLSTToken0_2) = 
            LSTDetection.detectLSTInPool(key2);
        
        // Both should detect the LST
        assertTrue(hasLST1);
        assertTrue(hasLST2);
        assertEq(lstToken1, lstToken2); // Same LST detected
        assertEq(pairedToken1, pairedToken2); // Same paired token
        assertTrue(isLSTToken0_1); // STETH is token0 in first case
        assertFalse(isLSTToken0_2); // STETH is token1 in second case
    }
    
    function test_detectLSTInPool_AllLSTsAsToken1_WithWETH() public {
        address[6] memory lsts = [STETH, RETH, CBETH, SFRXETH, SWETH, ANKRETH];
        
        for (uint i = 0; i < lsts.length; i++) {
            PoolKey memory key = _createPoolKey(WETH, lsts[i]);
            (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
                LSTDetection.detectLSTInPool(key);
            
            assertTrue(hasLST);
            assertEq(lstToken, lsts[i]);
            assertEq(pairedToken, WETH);
            assertFalse(isLSTToken0);
        }
    }

    // ============ Unit Tests for detectLSTInPool - No LST Cases (15 tests) ============
    
    function test_detectLSTInPool_ReturnsFalse_ForNonLSTTokens() public {
        PoolKey memory key = _createPoolKey(WETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_ReturnsFalse_ForStablecoinPair() public {
        PoolKey memory key = _createPoolKey(USDC, DAI);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_ReturnsFalse_ForZeroAddresses() public {
        PoolKey memory key = _createPoolKey(address(0), address(0));
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_ReturnsFalse_ForRandomAddresses() public {
        address random1 = address(0x1111111111111111111111111111111111111111);
        address random2 = address(0x2222222222222222222222222222222222222222);
        
        PoolKey memory key = _createPoolKey(random1, random2);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_ReturnsFalse_ForContractAddresses() public {
        PoolKey memory key = _createPoolKey(address(this), msg.sender);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_ReturnsFalse_ForSameNonLSTToken() public {
        PoolKey memory key = _createPoolKey(WETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_ReturnsFalse_ForMaxAddresses() public {
        address max1 = address(type(uint160).max);
        address max2 = address(type(uint160).max - 1);
        
        PoolKey memory key = _createPoolKey(max1, max2);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_ReturnsFalse_ForLowValueAddresses() public {
        PoolKey memory key = _createPoolKey(address(1), address(2));
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_ReturnsFalse_ForMixedAddressTypes() public {
        PoolKey memory key = _createPoolKey(address(0), WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_ConsistentOutput_ForNoLSTCases() public {
        address[3] memory nonLSTs = [WETH, USDC, DAI];
        
        for (uint i = 0; i < nonLSTs.length; i++) {
            for (uint j = i + 1; j < nonLSTs.length; j++) {
                PoolKey memory key = _createPoolKey(nonLSTs[i], nonLSTs[j]);
                (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
                    LSTDetection.detectLSTInPool(key);
                
                assertFalse(hasLST);
                assertEq(lstToken, address(0));
                assertEq(pairedToken, address(0));
                assertFalse(isLSTToken0);
            }
        }
    }
    
    function test_detectLSTInPool_EdgeCase_WithSequentialAddresses() public {
        address addr1 = address(0x1000000000000000000000000000000000000000);
        address addr2 = address(0x1000000000000000000000000000000000000001);
        
        PoolKey memory key = _createPoolKey(addr1, addr2);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_EdgeCase_WithHighValueAddresses() public {
        address high1 = address(0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        address high2 = address(0xfFfFFffFffffFFffFffFFFFFFfFFFfFfFFfFfFfD);
        
        PoolKey memory key = _createPoolKey(high1, high2);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_EdgeCase_WithCommonPatterns() public {
        // Test common address patterns that might appear in real scenarios
        address pattern1 = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
        address pattern2 = address(0xCafEBAbECAFEbAbEcaFEbabECAfebAbEcAFEBaBe);
        
        PoolKey memory key = _createPoolKey(pattern1, pattern2);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_EdgeCase_WithAlmostLSTAddresses() public {
        // Addresses that are similar to LST addresses but not exact matches
        address almostStETH = address(0xAE7AB96520DE3A18e5e111b5eAAB095312D7fe85); // Last byte different
        address almostRETH = address(0xAE78736cd615F374d3085123A210448e74fC6392); // Last byte different
        
        PoolKey memory key = _createPoolKey(almostStETH, almostRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function test_detectLSTInPool_StressTest_MultipleNonLSTCombinations() public {
        address[5] memory nonLSTs = [
            WETH, 
            USDC, 
            DAI, 
            address(0x1111111111111111111111111111111111111111),
            address(0x2222222222222222222222222222222222222222)
        ];
        
        // Test all combinations
        for (uint i = 0; i < nonLSTs.length; i++) {
            for (uint j = 0; j < nonLSTs.length; j++) {
                if (i != j) { // Skip same token pairs
                    PoolKey memory key = _createPoolKey(nonLSTs[i], nonLSTs[j]);
                    (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
                        LSTDetection.detectLSTInPool(key);
                    
                    assertFalse(hasLST);
                    assertEq(lstToken, address(0));
                    assertEq(pairedToken, address(0));
                    assertFalse(isLSTToken0);
                }
            }
        }
    }
}