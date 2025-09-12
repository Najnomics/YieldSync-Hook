// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";

/**
 * @title LSTDetection
 * @dev Library for detecting LST tokens in Uniswap pools
 */
library LSTDetection {
    using CurrencyLibrary for Currency;

    /// @notice Known LST token addresses on mainnet
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant CBETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address public constant SFRXETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address public constant SWETH = 0xf951E335afb289353dc249e82926178EaC7DEd78;
    address public constant ANKRETH = 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb;

    /// @notice Detect LST token in pool
    /// @param key The pool key
    /// @return hasLST Whether pool contains an LST
    /// @return lstToken The LST token address
    /// @return pairedToken The paired token address
    /// @return isLSTToken0 Whether LST is token0
    function detectLSTInPool(PoolKey calldata key) 
        internal 
        pure 
        returns (
            bool hasLST,
            address lstToken,
            address pairedToken,
            bool isLSTToken0
        ) 
    {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        
        if (_isLST(token0)) {
            return (true, token0, token1, true);
        }
        if (_isLST(token1)) {
            return (true, token1, token0, false);
        }
        return (false, address(0), address(0), false);
    }

    /// @notice Check if token is a known LST
    /// @param token The token address
    /// @return isLST Whether token is an LST
    function _isLST(address token) internal pure returns (bool isLST) {
        return token == STETH ||
               token == RETH ||
               token == CBETH ||
               token == SFRXETH ||
               token == SWETH ||
               token == ANKRETH;
    }

    /// @notice Get LST token name
    /// @param token The token address
    /// @return name The LST token name
    function getLSTName(address token) internal pure returns (string memory name) {
        if (token == STETH) return "stETH";
        if (token == RETH) return "rETH";
        if (token == CBETH) return "cbETH";
        if (token == SFRXETH) return "sfrxETH";
        if (token == SWETH) return "swETH";
        if (token == ANKRETH) return "ankrETH";
        return "Unknown LST";
    }

    /// @notice Get LST token symbol
    /// @param token The token address
    /// @return symbol The LST token symbol
    function getLSTSymbol(address token) internal pure returns (string memory symbol) {
        if (token == STETH) return "stETH";
        if (token == RETH) return "rETH";
        if (token == CBETH) return "cbETH";
        if (token == SFRXETH) return "sfrxETH";
        if (token == SWETH) return "swETH";
        if (token == ANKRETH) return "ankrETH";
        return "UNKNOWN";
    }

    /// @notice Get expected yield range for LST
    /// @param token The token address
    /// @return minYieldBPS Minimum expected yield in basis points
    /// @return maxYieldBPS Maximum expected yield in basis points
    function getExpectedYieldRange(address token) 
        internal 
        pure 
        returns (uint256 minYieldBPS, uint256 maxYieldBPS) 
    {
        if (token == STETH) {
            return (300, 600); // 3-6% annual yield
        }
        if (token == RETH) {
            return (300, 600); // 3-6% annual yield
        }
        if (token == CBETH) {
            return (250, 550); // 2.5-5.5% annual yield
        }
        if (token == SFRXETH) {
            return (300, 600); // 3-6% annual yield
        }
        if (token == SWETH) {
            return (300, 600); // 3-6% annual yield
        }
        if (token == ANKRETH) {
            return (300, 600); // 3-6% annual yield
        }
        return (0, 0); // Unknown LST
    }

    /// @notice Check if token pair is LST-related
    /// @param token0 First token address
    /// @param token1 Second token address
    /// @return isLSTPair Whether this is an LST-related pair
    function isLSTPair(address token0, address token1) internal pure returns (bool) {
        return _isLST(token0) || _isLST(token1);
    }

    /// @notice Get LST token from pair
    /// @param token0 First token address
    /// @param token1 Second token address
    /// @return lstToken The LST token address (address(0) if none)
    function getLSTFromPair(address token0, address token1) internal pure returns (address lstToken) {
        if (_isLST(token0)) return token0;
        if (_isLST(token1)) return token1;
        return address(0);
    }
}
