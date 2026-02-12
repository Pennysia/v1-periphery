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

    // function createPool(address)

    /// @dev token0 and token1 must be sorted, otherwise revert in createLiquidity()
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 dividerX128,
        uint256 fee,
        uint256 liquidityLongMinimum, //checked
        uint256 liquidityShortMinimum, //checked
        address to, //checked
        uint256 deadline //checked
    )
        external
        payable
        override
        ensure(deadline)
        returns (
            uint256 pairId,
            uint256 amount0Required,
            uint256 amount1Required,
            uint256 liquidityLong,
            uint256 liquidityShort
        )
    {
        Validation.notThis(to);

        (pairId, amount0Required, amount1Required, liquidityLong, liquidityShort) =
            IMarket(market).deposit(to, token0, token1, amount0, amount1, dividerX128, fee);

        require(liquidityLong >= liquidityLongMinimum, slippage());
        require(liquidityShort >= liquidityShortMinimum, slippage());

        // address payer = msg.sender;

        // Payment.requestToken(payer, new address[](2){token0, token1}, new uint256[](2){amount0Required, amount1Required});

        // refundNative(payer);
    }

    /// @dev token0 and token1 must be sorted, otherwise revert in withdrawLiquidity()
    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidityLong,
        uint256 liquidityShort,
        uint256 amount0Minimum,
        uint256 amount1Minimum,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) returns (uint256 amount0, uint256 amount1) {
        Validation.notThis(to);
        (, amount0, amount1) = IMarket(market).withdraw(to, token0, token1, liquidityLong, liquidityShort);
        require(amount0 >= amount0Minimum, slippage());
        require(amount1 >= amount1Minimum, slippage());
        refundNative(to);
    }

    /// @dev token0 and token1 must be sorted, otherwise revert in withdrawLiquidity()
    function swapLiquidity(
        address token0,
        address token1,
        bool longToShort,
        uint256 liquidityIn,
        uint256 liquidityOutMinimum,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) returns (uint256 liquidityOut) {
        Validation.notThis(to);
        (, liquidityOut) = IMarket(market).lpSwap(to, token0, token1, longToShort, liquidityIn);
        require(liquidityOut >= liquidityOutMinimum, slippage());
        refundNative(to);
    }

    /// @dev path must be sorted, otherwise revert in swapToken()
    function swapToken(
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) returns (uint256 amountOut) {
        Validation.notThis(to);
        amountOut = IMarket(market).swap(to, path, amountIn);
        require(amountOut >= amountOutMinimum, slippage());
        refundNative(to);
    }
}
