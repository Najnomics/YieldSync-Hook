// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";

/**
 * @dev Simplified mock for testing hooks - only implements what we need
 */
contract MockPoolManager {
    mapping(bytes32 => bool) public poolExists;
    mapping(bytes32 => uint160) public poolSqrtPrices;
    address public mockCaller;
    
    struct ModifyLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
    }

    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }
    
    function setMockCaller(address caller) external {
        mockCaller = caller;
    }
    
    function mockInitialize(PoolKey memory key, uint160 sqrtPriceX96) external {
        bytes32 id = keccak256(abi.encode(key));
        poolExists[id] = true;
        poolSqrtPrices[id] = sqrtPriceX96;
    }
    
    function isPoolInitialized(PoolKey memory key) external view returns (bool) {
        bytes32 id = keccak256(abi.encode(key));
        return poolExists[id];
    }
    
    function getPoolSqrtPrice(PoolKey memory key) external view returns (uint160) {
        bytes32 id = keccak256(abi.encode(key));
        return poolSqrtPrices[id];
    }
}