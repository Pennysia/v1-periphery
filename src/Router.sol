// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.28;

import {Deadline} from "./abstract/Deadline.sol";
import {Multicall} from "./abstract/Multicall.sol";

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {RouterLibrary} from "./libraries/RouterLibrary.sol";

import {ILiquidity} from "./interfaces/ILiquidity.sol";
import {IMarket} from "./interfaces/IMarket.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {IPayment} from "./interfaces/IPayment.sol";

contract Router is Deadline, Multicall, IRouter, IPayment {
    address public immutable market;

    constructor(address _market) {
        market = _market;
    }

    //-------- Library Functions --------
    function quoteLiquidity(
        address token0,
        address token1,
        uint256 amountLong0,
        uint256 amountShort0,
        uint256 amountLong1,
        uint256 amountShort1
    ) public view override returns (uint256 longX, uint256 shortX, uint256 longY, uint256 shortY) {
        return
            RouterLibrary.quoteLiquidity(market, token0, token1, amountLong0, amountShort0, amountLong1, amountShort1);
    }

    function quoteReserve(address token0, address token1, uint256 longX, uint256 shortX, uint256 longY, uint256 shortY)
        public
        view
        override
        returns (uint256 amountLong0, uint256 amountShort0, uint256 amountLong1, uint256 amountShort1)
    {
        return RouterLibrary.quoteReserve(market, token0, token1, longX, shortX, longY, shortY);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        override
        returns (uint256 amountOut)
    {
        return RouterLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        override
        returns (uint256 amountIn)
    {
        return RouterLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        return RouterLibrary.getAmountsOut(market, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        return RouterLibrary.getAmountsIn(market, amountOut, path);
    }

    // --------- Sweep Leftover Native Token ---------

    function sweepNative(address to) public override {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            TransferHelper.safeTransfer(address(0), to, balance);
        }
    }

    // --------- Liquidity Functions ---------
    /// @dev token0 and token1 must be sorted, otherwise revert in createLiquidity()
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Long,
        uint256 amount0Short,
        uint256 amount1Long,
        uint256 amount1Short,
        uint256 longXMinimum,
        uint256 shortXMinimum,
        uint256 longYMinimum,
        uint256 shortYMinimum,
        address to,
        uint256 deadline
    )
        external
        payable
        override
        ensure(deadline)
        returns (uint256 longX, uint256 shortX, uint256 longY, uint256 shortY)
    {
        (, longX, shortX, longY, shortY) =
            IMarket(market).createLiquidity(to, token0, token1, amount0Long, amount0Short, amount1Long, amount1Short);

        require(longX >= longXMinimum, slippage());
        require(shortX >= shortXMinimum, slippage());
        require(longY >= longYMinimum, slippage());
        require(shortY >= shortYMinimum, slippage());
        sweepNative(to);
    }

    function removeLiquidity(
        address token0,
        address token1,
        uint256 longX,
        uint256 shortX,
        uint256 longY,
        uint256 shortY,
        uint256 amount0Minimum,
        uint256 amount1Minimum,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) returns (uint256 amount0, uint256 amount1) {
        (, amount0, amount1) = IMarket(market).withdrawLiquidity(to, token0, token1, longX, shortX, longY, shortY);

        require(amount0 >= amount0Minimum, slippage());
        require(amount1 >= amount1Minimum, slippage());
        sweepNative(to);
    }

    // --------- Swap Function ---------
    function swap(uint256 amountIn, uint256 amountOutMinimum, address[] calldata path, address to, uint256 deadline)
        external
        payable
        override
        ensure(deadline)
        returns (uint256 amountOut)
    {
        amountOut = IMarket(market).swap(to, path, amountIn);
        require(amountOut >= amountOutMinimum, slippage());
        sweepNative(to);
    }

    // --------- Payment Functions ---------
    function requestToken(address to, address[] memory tokens, uint256[] memory paybackAmounts)
        external
        payable
        override
    {
        require(msg.sender == market, forbidden());
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                TransferHelper.safeTransfer(address(0), market, paybackAmounts[i]);
            } else {
                TransferHelper.safeTransferFrom(tokens[i], to, market, paybackAmounts[i]);
            }
        }
    }

    function requestLiquidity(
        address to,
        uint256 poolId,
        uint128 amountForLongX,
        uint128 amountForShortX,
        uint128 amountForLongY,
        uint128 amountForShortY
    ) external override {
        require(msg.sender == market, forbidden());
        ILiquidity(market).transferFrom(
            to, address(0), poolId, amountForLongX, amountForShortX, amountForLongY, amountForShortY
        );
    }
}
