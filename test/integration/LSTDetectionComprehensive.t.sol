// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/hooks/libraries/LSTDetection.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";

/**
 * @title LSTDetectionComprehensiveTest
 * @dev Comprehensive test suite for LST Detection library - 100 test cases
 */
contract LSTDetectionComprehensiveTest is Test {
    
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
    address public constant ZERO_ADDRESS = address(0);
    
    function _createPoolKey(address token0, address token1) internal pure returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    // ============ LST Token Detection Tests (20 tests) ============
    
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
    
    function testIsNotLSTWETH() public {
        assertFalse(LSTDetection._isLST(WETH));
    }
    
    function testIsNotLSTUSDC() public {
        assertFalse(LSTDetection._isLST(USDC));
    }
    
    function testIsNotLSTDAI() public {
        assertFalse(LSTDetection._isLST(DAI));
    }
    
    function testIsNotLSTZeroAddress() public {
        assertFalse(LSTDetection._isLST(ZERO_ADDRESS));
    }
    
    function testIsNotLSTRandomAddress1() public {
        assertFalse(LSTDetection._isLST(address(0x1234567890123456789012345678901234567890)));
    }
    
    function testIsNotLSTRandomAddress2() public {
        assertFalse(LSTDetection._isLST(address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD)));
    }
    
    function testIsNotLSTRandomAddress3() public {
        assertFalse(LSTDetection._isLST(address(0x9999999999999999999999999999999999999999)));
    }
    
    function testIsNotLSTRandomAddress4() public {
        assertFalse(LSTDetection._isLST(address(0x1111111111111111111111111111111111111111)));
    }
    
    function testIsNotLSTRandomAddress5() public {
        assertFalse(LSTDetection._isLST(address(0x2222222222222222222222222222222222222222)));
    }
    
    function testIsNotLSTContract() public {
        assertFalse(LSTDetection._isLST(address(this)));
    }
    
    function testIsNotLSTMsgSender() public {
        assertFalse(LSTDetection._isLST(msg.sender));
    }
    
    function testIsNotLSTTxOrigin() public {
        assertFalse(LSTDetection._isLST(tx.origin));
    }
    
    function testIsNotLSTMaxAddress() public {
        assertFalse(LSTDetection._isLST(address(type(uint160).max)));
    }
    
    function testIsNotLSTLowAddress() public {
        assertFalse(LSTDetection._isLST(address(1)));
    }

    // ============ Pool Detection Tests - LST as Token0 (15 tests) ============
    
    function testDetectLSTInPoolStETHFirst() public {
        PoolKey memory key = _createPoolKey(STETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolRETHFirst() public {
        PoolKey memory key = _createPoolKey(RETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolCBETHFirst() public {
        PoolKey memory key = _createPoolKey(CBETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolSFRXETHFirst() public {
        PoolKey memory key = _createPoolKey(SFRXETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolSWETHFirst() public {
        PoolKey memory key = _createPoolKey(SWETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolANKRETHFirst() public {
        PoolKey memory key = _createPoolKey(ANKRETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, ANKRETH);
        assertEq(pairedToken, WETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolStETHWithUSDC() public {
        PoolKey memory key = _createPoolKey(STETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, USDC);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolStETHWithDAI() public {
        PoolKey memory key = _createPoolKey(STETH, DAI);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, DAI);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolRETHWithUSDC() public {
        PoolKey memory key = _createPoolKey(RETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, USDC);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolRETHWithDAI() public {
        PoolKey memory key = _createPoolKey(RETH, DAI);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, DAI);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolCBETHWithUSDC() public {
        PoolKey memory key = _createPoolKey(CBETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, USDC);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolCBETHWithDAI() public {
        PoolKey memory key = _createPoolKey(CBETH, DAI);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, DAI);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolSFRXETHWithUSDC() public {
        PoolKey memory key = _createPoolKey(SFRXETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, USDC);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolSWETHWithUSDC() public {
        PoolKey memory key = _createPoolKey(SWETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, USDC);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolANKRETHWithUSDC() public {
        PoolKey memory key = _createPoolKey(ANKRETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, ANKRETH);
        assertEq(pairedToken, USDC);
        assertTrue(isLSTToken0);
    }

    // ============ Pool Detection Tests - LST as Token1 (15 tests) ============
    
    function testDetectLSTInPoolStETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, STETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolRETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, RETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolCBETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, CBETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolSFRXETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, SFRXETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolSWETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, SWETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolANKRETHSecond() public {
        PoolKey memory key = _createPoolKey(WETH, ANKRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, ANKRETH);
        assertEq(pairedToken, WETH);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolUSDCStETH() public {
        PoolKey memory key = _createPoolKey(USDC, STETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, USDC);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolDAIStETH() public {
        PoolKey memory key = _createPoolKey(DAI, STETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, DAI);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolUSDCRETH() public {
        PoolKey memory key = _createPoolKey(USDC, RETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, USDC);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolDAIRETH() public {
        PoolKey memory key = _createPoolKey(DAI, RETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, DAI);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolUSDCCBETH() public {
        PoolKey memory key = _createPoolKey(USDC, CBETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, USDC);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolDAICBETH() public {
        PoolKey memory key = _createPoolKey(DAI, CBETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, DAI);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolUSDCSFRXETH() public {
        PoolKey memory key = _createPoolKey(USDC, SFRXETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, USDC);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolUSDCSWETH() public {
        PoolKey memory key = _createPoolKey(USDC, SWETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, USDC);
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolUSDCANKRETH() public {
        PoolKey memory key = _createPoolKey(USDC, ANKRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, ANKRETH);
        assertEq(pairedToken, USDC);
        assertFalse(isLSTToken0);
    }

    // ============ Pool Detection Tests - No LST (15 tests) ============
    
    function testDetectLSTInPoolNoLSTWETHUSDC() public {
        PoolKey memory key = _createPoolKey(WETH, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTWETHDAI() public {
        PoolKey memory key = _createPoolKey(WETH, DAI);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTUSDCDAI() public {
        PoolKey memory key = _createPoolKey(USDC, DAI);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTRandomTokens() public {
        PoolKey memory key = _createPoolKey(
            address(0x1234567890123456789012345678901234567890),
            address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD)
        );
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTZeroAddresses() public {
        PoolKey memory key = _createPoolKey(ZERO_ADDRESS, ZERO_ADDRESS);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTWETHZero() public {
        PoolKey memory key = _createPoolKey(WETH, ZERO_ADDRESS);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTZeroWETH() public {
        PoolKey memory key = _createPoolKey(ZERO_ADDRESS, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTSameToken() public {
        PoolKey memory key = _createPoolKey(WETH, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTSameUSDC() public {
        PoolKey memory key = _createPoolKey(USDC, USDC);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTContractAddress() public {
        PoolKey memory key = _createPoolKey(address(this), WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTMsgSender() public {
        PoolKey memory key = _createPoolKey(msg.sender, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTMaxAddress() public {
        PoolKey memory key = _createPoolKey(address(type(uint160).max), WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTLowAddress() public {
        PoolKey memory key = _createPoolKey(address(1), address(2));
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTHighAddresses() public {
        PoolKey memory key = _createPoolKey(
            address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
        );
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testDetectLSTInPoolNoLSTSequentialAddresses() public {
        PoolKey memory key = _createPoolKey(
            address(0x1000000000000000000000000000000000000000),
            address(0x2000000000000000000000000000000000000000)
        );
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }

    // ============ Edge Cases and Special Scenarios (20 tests) ============
    
    function testDetectLSTInPoolBothLSTStETHRETH() public {
        PoolKey memory key = _createPoolKey(STETH, RETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH); // Should detect the first one (token0)
        assertEq(pairedToken, RETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTRETHStETH() public {
        PoolKey memory key = _createPoolKey(RETH, STETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH); // Should detect the first one (token0)
        assertEq(pairedToken, STETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTCBETHSFRXETH() public {
        PoolKey memory key = _createPoolKey(CBETH, SFRXETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH); // Should detect the first one (token0)
        assertEq(pairedToken, SFRXETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTSWETHANKRETH() public {
        PoolKey memory key = _createPoolKey(SWETH, ANKRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH); // Should detect the first one (token0)
        assertEq(pairedToken, ANKRETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations1() public {
        PoolKey memory key = _createPoolKey(STETH, CBETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, CBETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations2() public {
        PoolKey memory key = _createPoolKey(STETH, SFRXETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, SFRXETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations3() public {
        PoolKey memory key = _createPoolKey(STETH, SWETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, SWETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations4() public {
        PoolKey memory key = _createPoolKey(STETH, ANKRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, ANKRETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations5() public {
        PoolKey memory key = _createPoolKey(RETH, CBETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, CBETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations6() public {
        PoolKey memory key = _createPoolKey(RETH, SFRXETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, SFRXETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations7() public {
        PoolKey memory key = _createPoolKey(RETH, SWETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, SWETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations8() public {
        PoolKey memory key = _createPoolKey(RETH, ANKRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, ANKRETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations9() public {
        PoolKey memory key = _createPoolKey(CBETH, SWETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, SWETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations10() public {
        PoolKey memory key = _createPoolKey(CBETH, ANKRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, ANKRETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations11() public {
        PoolKey memory key = _createPoolKey(SFRXETH, SWETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, SWETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolBothLSTAllCombinations12() public {
        PoolKey memory key = _createPoolKey(SFRXETH, ANKRETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, ANKRETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolSameLSTStETH() public {
        PoolKey memory key = _createPoolKey(STETH, STETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, STETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolSameLSTRETH() public {
        PoolKey memory key = _createPoolKey(RETH, RETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, RETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolSameLSTCBETH() public {
        PoolKey memory key = _createPoolKey(CBETH, CBETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, CBETH);
        assertTrue(isLSTToken0);
    }
    
    function testDetectLSTInPoolSameLSTSFRXETH() public {
        PoolKey memory key = _createPoolKey(SFRXETH, SFRXETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, SFRXETH);
        assertTrue(isLSTToken0);
    }

    // ============ Fuzz Testing (15 tests) ============
    
    function testFuzzDetectLSTInPoolRandomToken0(address randomToken) public {
        vm.assume(randomToken != STETH && randomToken != RETH && randomToken != CBETH && 
                 randomToken != SFRXETH && randomToken != SWETH && randomToken != ANKRETH);
        
        PoolKey memory key = _createPoolKey(randomToken, WETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolRandomToken1(address randomToken) public {
        vm.assume(randomToken != STETH && randomToken != RETH && randomToken != CBETH && 
                 randomToken != SFRXETH && randomToken != SWETH && randomToken != ANKRETH);
        
        PoolKey memory key = _createPoolKey(WETH, randomToken);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolBothRandom(address randomToken1, address randomToken2) public {
        vm.assume(randomToken1 != STETH && randomToken1 != RETH && randomToken1 != CBETH && 
                 randomToken1 != SFRXETH && randomToken1 != SWETH && randomToken1 != ANKRETH);
        vm.assume(randomToken2 != STETH && randomToken2 != RETH && randomToken2 != CBETH && 
                 randomToken2 != SFRXETH && randomToken2 != SWETH && randomToken2 != ANKRETH);
        
        PoolKey memory key = _createPoolKey(randomToken1, randomToken2);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertFalse(hasLST);
        assertEq(lstToken, address(0));
        assertEq(pairedToken, address(0));
        assertFalse(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolStETHWithRandom(address randomToken) public {
        vm.assume(randomToken != STETH);
        
        PoolKey memory key = _createPoolKey(STETH, randomToken);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, randomToken);
        assertTrue(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolRandomWithStETH(address randomToken) public {
        vm.assume(randomToken != STETH);
        
        PoolKey memory key = _createPoolKey(randomToken, STETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, STETH);
        assertEq(pairedToken, randomToken);
        assertFalse(isLSTToken0);
    }
    
    function testFuzzIsLSTRandomAddress(address randomToken) public {
        vm.assume(randomToken != STETH && randomToken != RETH && randomToken != CBETH && 
                 randomToken != SFRXETH && randomToken != SWETH && randomToken != ANKRETH);
        
        assertFalse(LSTDetection._isLST(randomToken));
    }
    
    function testFuzzDetectLSTInPoolRETHWithRandom(address randomToken) public {
        vm.assume(randomToken != RETH);
        
        PoolKey memory key = _createPoolKey(RETH, randomToken);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, randomToken);
        assertTrue(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolRandomWithRETH(address randomToken) public {
        vm.assume(randomToken != RETH);
        
        PoolKey memory key = _createPoolKey(randomToken, RETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, RETH);
        assertEq(pairedToken, randomToken);
        assertFalse(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolCBETHWithRandom(address randomToken) public {
        vm.assume(randomToken != CBETH);
        
        PoolKey memory key = _createPoolKey(CBETH, randomToken);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, randomToken);
        assertTrue(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolRandomWithCBETH(address randomToken) public {
        vm.assume(randomToken != CBETH);
        
        PoolKey memory key = _createPoolKey(randomToken, CBETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, CBETH);
        assertEq(pairedToken, randomToken);
        assertFalse(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolSFRXETHWithRandom(address randomToken) public {
        vm.assume(randomToken != SFRXETH);
        
        PoolKey memory key = _createPoolKey(SFRXETH, randomToken);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, randomToken);
        assertTrue(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolRandomWithSFRXETH(address randomToken) public {
        vm.assume(randomToken != SFRXETH);
        
        PoolKey memory key = _createPoolKey(randomToken, SFRXETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SFRXETH);
        assertEq(pairedToken, randomToken);
        assertFalse(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolSWETHWithRandom(address randomToken) public {
        vm.assume(randomToken != SWETH);
        
        PoolKey memory key = _createPoolKey(SWETH, randomToken);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, randomToken);
        assertTrue(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolRandomWithSWETH(address randomToken) public {
        vm.assume(randomToken != SWETH);
        
        PoolKey memory key = _createPoolKey(randomToken, SWETH);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, SWETH);
        assertEq(pairedToken, randomToken);
        assertFalse(isLSTToken0);
    }
    
    function testFuzzDetectLSTInPoolANKRETHWithRandom(address randomToken) public {
        vm.assume(randomToken != ANKRETH);
        
        PoolKey memory key = _createPoolKey(ANKRETH, randomToken);
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        assertTrue(hasLST);
        assertEq(lstToken, ANKRETH);
        assertEq(pairedToken, randomToken);
        assertTrue(isLSTToken0);
    }
}