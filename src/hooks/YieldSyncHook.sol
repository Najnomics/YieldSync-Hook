// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import "../avs/interfaces/IYieldSyncAVS.sol";
import "../hooks/interfaces/IYieldSyncHook.sol";
import "../hooks/libraries/YieldCalculations.sol";
import "../hooks/libraries/PositionAdjustment.sol";
import "../hooks/libraries/LSTDetection.sol";

/**
 * @title YieldSyncHook
 * @dev Main Uniswap V4 Hook for automatic LST position adjustment
 * @notice Automatically adjusts LP positions based on LST yield data from EigenLayer AVS
 */
contract YieldSyncHook is BaseHook, ReentrancyGuard, Ownable, Pausable, IYieldSyncHook {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using YieldCalculations for YieldCalculations.YieldData;
    using PositionAdjustment for PositionAdjustment.PositionData;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Minimum adjustment threshold (0.1%)
    uint256 public constant MIN_ADJUSTMENT_THRESHOLD = 10;
    
    /// @notice Maximum adjustment threshold (5%)
    uint256 public constant MAX_ADJUSTMENT_THRESHOLD = 500;
    
    /// @notice Adjustment cooldown period (6 hours)
    uint256 public constant ADJUSTMENT_COOLDOWN = 21600;
    
    /// @notice Basis points denominator
    uint256 public constant BASIS_POINTS = 10000;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    
    /// @notice EigenLayer AVS for yield data
    IYieldSyncAVS public immutable yieldSyncAVS;
    
    /// @notice Mapping of position ID to position data
    mapping(bytes32 => PositionAdjustment.PositionData) public positions;
    
    /// @notice Mapping of pool ID to LST configuration
    mapping(PoolId => LSTConfig) public poolConfigs;
    
    /// @notice Mapping of user to total IL prevented
    mapping(address => uint256) public totalILPrevented;
    
    /// @notice Mapping of pool ID to total liquidity
    mapping(PoolId => uint256) public totalLiquidity;
    
    /// @notice Mapping of pool ID to user liquidity
    mapping(PoolId => mapping(address => uint256)) public userLiquidity;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event PositionRegistered(
        bytes32 indexed positionId,
        address indexed owner,
        address indexed lstToken,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    );
    
    event PositionAdjusted(
        bytes32 indexed positionId,
        address indexed owner,
        int24 oldTickLower,
        int24 oldTickUpper,
        int24 newTickLower,
        int24 newTickUpper,
        uint256 yieldBPS,
        uint256 estimatedILPrevented
    );
    
    event PoolConfigured(
        PoolId indexed poolId,
        address indexed lstToken,
        address indexed pairedToken,
        bool autoAdjustmentEnabled
    );
    
    event YieldDataUpdated(
        address indexed lstToken,
        uint256 yieldRate,
        uint256 timestamp
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    
    modifier onlyPositionOwner(bytes32 positionId) {
        require(positions[positionId].owner == msg.sender, "YieldSync: not position owner");
        _;
    }
    
    modifier onlyValidPosition(bytes32 positionId) {
        require(positions[positionId].owner != address(0), "YieldSync: position not found");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    constructor(
        IPoolManager _poolManager,
        IYieldSyncAVS _yieldSyncAVS
    ) BaseHook(_poolManager) Ownable(msg.sender) {
        yieldSyncAVS = _yieldSyncAVS;
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Returns the hook's permissions
     */
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,           // Configure LST pools
            beforeAddLiquidity: false,
            afterAddLiquidity: true,         // Register new positions
            beforeRemoveLiquidity: true,     // Check for yield adjustment before removal
            afterRemoveLiquidity: true,      // Clean up position tracking
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
    
    /**
     * @notice Called after pool initialization to configure LST detection
     */
    function afterInitialize(
        address,
        PoolKey calldata key,
        uint160,
        int24,
        bytes calldata
    ) external override returns (bytes4) {
        PoolId poolId = key.toId();
        
        // Auto-detect LST in pool
        (bool hasLST, address lstToken, address pairedToken, bool isLSTToken0) = 
            LSTDetection.detectLSTInPool(key);
        
        if (hasLST) {
            poolConfigs[poolId] = LSTConfig({
                lstToken: lstToken,
                pairedToken: pairedToken,
                isLSTToken0: isLSTToken0,
                adjustmentThresholdBPS: 50,  // Default 0.5% threshold
                autoAdjustmentEnabled: true
            });
            
            emit PoolConfigured(poolId, lstToken, pairedToken, true);
        }
        
        return BaseHook.afterInitialize.selector;
    }
    
    /**
     * @notice Called after adding liquidity to register positions
     */
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        LSTConfig memory config = poolConfigs[poolId];
        
        // Only track positions in LST pools with positive liquidity
        if (config.lstToken != address(0) && params.liquidityDelta > 0) {
            bytes32 positionId = _getPositionId(sender, poolId, params.tickLower, params.tickUpper);
            
            positions[positionId] = PositionAdjustment.PositionData({
                owner: sender,
                poolId: poolId,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidity: uint128(uint256(params.liquidityDelta)),
                lstToken: config.lstToken,
                lastYieldAdjustment: block.timestamp,
                accumulatedYieldBPS: 0,
                autoAdjustEnabled: true
            });
            
            // Update liquidity tracking
            userLiquidity[poolId][sender] += uint256(params.liquidityDelta);
            totalLiquidity[poolId] += uint256(params.liquidityDelta);
            
            emit PositionRegistered(
                positionId, 
                sender, 
                config.lstToken, 
                params.tickLower, 
                params.tickUpper,
                uint128(uint256(params.liquidityDelta))
            );
        }
        
        return (BaseHook.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }
    
    /**
     * @notice Called before removing liquidity to check for yield adjustments
     */
    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata
    ) external override returns (bytes4) {
        PoolId poolId = key.toId();
        LSTConfig memory config = poolConfigs[poolId];
        
        // Check for yield adjustment before position removal
        if (config.lstToken != address(0) && config.autoAdjustmentEnabled) {
            bytes32 positionId = _getPositionId(msg.sender, poolId, params.tickLower, params.tickUpper);
            _checkAndAdjustPosition(positionId);
        }
        
        return BaseHook.beforeRemoveLiquidity.selector;
    }
    
    /**
     * @notice Called after removing liquidity to clean up tracking
     */
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        
        // Update liquidity tracking
        if (params.liquidityDelta < 0) {
            uint256 liquidityRemoved = uint256(-int256(params.liquidityDelta));
            userLiquidity[poolId][sender] -= liquidityRemoved;
            totalLiquidity[poolId] -= liquidityRemoved;
        }
        
        return (BaseHook.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /*//////////////////////////////////////////////////////////////
                           POSITION FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Check and adjust position based on yield data
     * @param positionId The position ID to check
     */
    function _checkAndAdjustPosition(bytes32 positionId) internal {
        PositionAdjustment.PositionData storage position = positions[positionId];
        if (position.owner == address(0) || !position.autoAdjustEnabled) return;
        
        // Get required adjustment from AVS
        uint256 requiredAdjustmentBPS = yieldSyncAVS.getRequiredAdjustment(
            position.lstToken,
            position.lastYieldAdjustment
        );
        
        LSTConfig memory config = poolConfigs[position.poolId];
        
        // Check if adjustment is needed
        if (requiredAdjustmentBPS >= config.adjustmentThresholdBPS &&
            block.timestamp >= position.lastYieldAdjustment + ADJUSTMENT_COOLDOWN) {
            
            _executePositionAdjustment(positionId, requiredAdjustmentBPS);
        }
    }
    
    /**
     * @notice Execute position adjustment
     * @param positionId The position ID
     * @param yieldBPS The yield in basis points
     */
    function _executePositionAdjustment(
        bytes32 positionId,
        uint256 yieldBPS
    ) internal {
        PositionAdjustment.PositionData storage position = positions[positionId];
        LSTConfig memory config = poolConfigs[position.poolId];
        
        // Calculate new tick range based on yield accumulation
        (int24 newTickLower, int24 newTickUpper) = PositionAdjustment.calculateAdjustedTicks(
            position.tickLower,
            position.tickUpper,
            yieldBPS,
            config.isLSTToken0
        );
        
        // Estimate impermanent loss prevented
        uint256 estimatedILPrevented = YieldCalculations.calculateILPrevented(
            position.liquidity,
            yieldBPS
        );
        
        // Store old values for event
        int24 oldTickLower = position.tickLower;
        int24 oldTickUpper = position.tickUpper;
        
        // Update position data
        position.tickLower = newTickLower;
        position.tickUpper = newTickUpper;
        position.lastYieldAdjustment = block.timestamp;
        position.accumulatedYieldBPS += yieldBPS;
        
        // Update user metrics
        totalILPrevented[position.owner] += estimatedILPrevented;
        
        emit PositionAdjusted(
            positionId,
            position.owner,
            oldTickLower,
            oldTickUpper,
            newTickLower,
            newTickUpper,
            yieldBPS,
            estimatedILPrevented
        );
    }
    
    /**
     * @notice Manually adjust a position
     * @param positionId The position ID to adjust
     */
    function manuallyAdjustPosition(bytes32 positionId) 
        external 
        onlyValidPosition(positionId) 
        onlyPositionOwner(positionId)
        nonReentrant
    {
        _checkAndAdjustPosition(positionId);
    }
    
    /**
     * @notice Set auto-adjustment for a position
     * @param positionId The position ID
     * @param enabled Whether to enable auto-adjustment
     */
    function setAutoAdjustment(bytes32 positionId, bool enabled) 
        external 
        onlyValidPosition(positionId) 
        onlyPositionOwner(positionId)
    {
        positions[positionId].autoAdjustEnabled = enabled;
    }
    
    /**
     * @notice Get position health metrics
     * @param positionId The position ID
     * @return currentYieldDrift Current yield drift in BPS
     * @return needsAdjustment Whether position needs adjustment
     * @return potentialILPrevention Potential IL prevention amount
     * @return timeSinceLastAdjustment Time since last adjustment
     */
    function getPositionHealth(bytes32 positionId) 
        external 
        view 
        returns (
            uint256 currentYieldDrift,
            bool needsAdjustment,
            uint256 potentialILPrevention,
            uint256 timeSinceLastAdjustment
        ) 
    {
        PositionAdjustment.PositionData memory position = positions[positionId];
        require(position.owner != address(0), "YieldSync: position not found");
        
        currentYieldDrift = yieldSyncAVS.getRequiredAdjustment(
            position.lstToken,
            position.lastYieldAdjustment
        );
        
        LSTConfig memory config = poolConfigs[position.poolId];
        needsAdjustment = currentYieldDrift >= config.adjustmentThresholdBPS;
        
        potentialILPrevention = YieldCalculations.calculateILPrevented(
            position.liquidity, 
            currentYieldDrift
        );
        timeSinceLastAdjustment = block.timestamp - position.lastYieldAdjustment;
        
        return (currentYieldDrift, needsAdjustment, potentialILPrevention, timeSinceLastAdjustment);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Configure pool LST settings
     * @param poolId The pool ID
     * @param config The LST configuration
     */
    function configurePool(PoolId poolId, LSTConfig calldata config) external onlyOwner {
        require(config.lstToken != address(0), "YieldSync: invalid LST token");
        require(config.adjustmentThresholdBPS >= MIN_ADJUSTMENT_THRESHOLD, "YieldSync: threshold too low");
        require(config.adjustmentThresholdBPS <= MAX_ADJUSTMENT_THRESHOLD, "YieldSync: threshold too high");
        
        poolConfigs[poolId] = config;
        emit PoolConfigured(poolId, config.lstToken, config.pairedToken, config.autoAdjustmentEnabled);
    }
    
    /**
     * @notice Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Generate position ID
     * @param owner The position owner
     * @param poolId The pool ID
     * @param tickLower The lower tick
     * @param tickUpper The upper tick
     * @return The position ID
     */
    function _getPositionId(
        address owner,
        PoolId poolId,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, poolId, tickLower, tickUpper));
    }
}
