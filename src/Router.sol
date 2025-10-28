// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

import {Deadline} from "./abstract/Deadline.sol";
import {Payment} from "./abstract/Payment.sol";
import {Multicall} from "./abstract/Multicall.sol";

import {Validation} from "./libraries/Validation.sol";

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
        Validation.notThis(to);
        uint256 marketPriceX128 = IMarket(market).getPriceX128(token0, token1);
        require(minPriceX128 <= marketPriceX128 && maxPriceX128 >= marketPriceX128, slippage());
        (, liquidityLong, liquidityShort) =
            IMarket(market).deposit(to, token0, token1, amount0, amount1, dividerX128, fee);
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
        Validation.notThis(to);
        uint256 marketPriceX128 = IMarket(market).getPriceX128(token0, token1);
        require(minPriceX128 <= marketPriceX128 && maxPriceX128 >= marketPriceX128, slippage());
        (, amount0, amount1) = IMarket(market).withdraw(to, token0, token1, liquidityLong, liquidityShort);
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
        Validation.notThis(to);
        uint256 marketPriceX128 = IMarket(market).getPriceX128(token0, token1);
        require(minPriceX128 <= marketPriceX128 && maxPriceX128 >= marketPriceX128, slippage());
        (, liquidityOut) = IMarket(market).lpSwap(to, token0, token1, longToShort, liquidityIn);
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
        Validation.notThis(to);
        amountOut = IMarket(market).swap(to, path, amountIn);
        require(amountOut >= amountOutMinimum, slippage());
        refundNative(to);
    }

    // ------------------ Fee Function ------------------

    function changeFee(address token0, address token1, uint256 fee) external override {
        IMarket(market).voteFee(token0, token1, msg.sender, fee);
    }
}
