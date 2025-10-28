// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

import {Deadline} from "./abstract/Deadline.sol";
import {Payment} from "./abstract/Payment.sol";
import {Multicall} from "./abstract/Multicall.sol";
import {IMarket} from "./interfaces/IMarket.sol";
import {IRouter} from "./interfaces/IRouter.sol";

contract Router is IRouter, Deadline, Payment, Multicall {
    constructor(address _market) Payment(_market) {}

    // ------------------ Liquidity Functions ------------------

    /// @dev token0 and token1 must be sorted, otherwise revert in createLiquidity()
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 dividerX128,
        uint256 fee, // min = 100(0.1%), max = 500(0.5%)
        uint256 minPriceX128, // slippage tolerance
        uint256 maxPriceX128, // slippage tolerance
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) returns (uint256 liquidityLong, uint256 liquidityShort) {
        (, liquidityLong, liquidityShort) = IMarket(market)
            .createLiquidity(to, token0, token1, amount0, amount1, dividerX128, fee, minPriceX128, maxPriceX128);
        refundNative(to);
    }

    /// @dev token0 and token1 must be sorted, otherwise revert in withdrawLiquidity()
    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidityLong,
        uint256 liquidityShort,
        uint256 minPriceX128, // slippage tolerance
        uint256 maxPriceX128, // slippage tolerance
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) returns (uint256 amount0, uint256 amount1) {
        (, amount0, amount1) = IMarket(market)
            .withdrawLiquidity(to, token0, token1, liquidityLong, liquidityShort, minPriceX128, maxPriceX128);
        refundNative(to);
    }

    /// @dev token0 and token1 must be sorted, otherwise revert in withdrawLiquidity()
    function liquiditySwap(
        address token0,
        address token1,
        bool longToShort,
        uint256 liquidityIn,
        uint256 minPriceX128, // slippage tolerance
        uint256 maxPriceX128, // slippage tolerance
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) returns (uint256 liquidityOut) {
        (, liquidityOut) =
            IMarket(market).lpSwap(to, token0, token1, longToShort, liquidityIn, minPriceX128, maxPriceX128);
        refundNative(to);
    }

    // ------------------ Swap Function ------------------

    function swap(uint256 amountIn, uint256 amountOutMinimum, address[] calldata path, address to, uint256 deadline)
        external
        payable
        override
        ensure(deadline)
        returns (uint256 amountOut)
    {
        amountOut = IMarket(market).swap(to, path, amountIn, amountOutMinimum);
        // require(amountOut >= amountOutMinimum, slippage());
        refundNative(to);
    }

    // ------------------ Fee Function ------------------

    function voteFee(address token0, address token1, uint256 fee) external override {
        IMarket(market).voteFee(token0, token1, msg.sender, fee);
    }
}
