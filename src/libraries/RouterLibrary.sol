// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {ILiquidity} from "../interfaces/ILiquidity.sol";
import {IMarket} from "../interfaces/IMarket.sol";
import {Math} from "./Math.sol";

library RouterLibrary {
    error identicalTokens();
    error pairZeroBalance();
    error invalidPath();
    error tokensNotSorted();
    error insufficientAmounts();

    function onlySorted(address tokenA, address tokenB) internal pure {
        require(tokenA < tokenB, tokensNotSorted());
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, identicalTokens());
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function computePairId(address token0, address token1) internal pure returns (uint256 pairId) {
        pairId = uint256(keccak256(abi.encodePacked(token0, token1)));
    }

    function getReserves(address market, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        (uint256 reserve0Long, uint256 reserve0Short, uint256 reserve1Long, uint256 reserve1Short) =
            getDirectionalBalances(market, token0, token1);

        uint256 reserve0 = reserve0Long + reserve0Short;
        uint256 reserve1 = reserve1Long + reserve1Short;
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // --------- Get Amounts ---------

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, insufficientAmounts());
        require(reserveIn > 0 && reserveOut > 0, pairZeroBalance());
        // Calculate amountOut using constant product formula: x * y = k
        uint256 newReserveIn = reserveIn + amountIn;
        uint256 newReserveOut = (reserveOut * reserveIn) / newReserveIn;
        amountOut = reserveOut - newReserveOut;
        // Deduct 0.3% fee from amountOut (matching Market.sol logic)
        uint256 feeAmountOut = (amountOut * 3 + 999) / 1000; // divUp equivalent
        amountOut -= feeAmountOut;
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, insufficientAmounts());
        require(reserveIn > 0 && reserveOut > 0, pairZeroBalance());
        uint256 amountOutWithFee = ((amountOut * 1003 + 999) / 1000); // divUp equivalent
        uint256 newReserveOut = reserveOut - amountOutWithFee;
        uint256 newReserveIn = (reserveIn * reserveOut) / newReserveOut;
        amountIn = newReserveIn - reserveIn;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address market, uint256 amountIn, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, invalidPath());
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(market, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address market, uint256 amountOut, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, invalidPath());
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(market, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    // --------- Liquidity Functions ---------
    ///@dev token0 and token1 must be sorted
    function getDirectionalBalances(address market, address token0, address token1)
        internal
        view
        returns (uint256 reserve0Long, uint256 reserve0Short, uint256 reserve1Long, uint256 reserve1Short)
    {
        onlySorted(token0, token1);
        uint256 pairId = computePairId(token0, token1);
        (reserve0Long, reserve0Short, reserve1Long, reserve1Short) = IMarket(market).getReserves(pairId);
    }

    ///@dev token0 and token1 must be sorted
    function getLiquiditySupply(address market, address token0, address token1)
        internal
        view
        returns (uint256 longX, uint256 shortX, uint256 longY, uint256 shortY)
    {
        onlySorted(token0, token1);
        uint256 poolId = computePairId(token0, token1);

        (longX, shortX, longY, shortY) = ILiquidity(market).totalSupply(poolId);
    }

    function quoteLiquidity(
        address market,
        address token0,
        address token1,
        uint256 amountLong0,
        uint256 amountShort0,
        uint256 amountLong1,
        uint256 amountShort1
    ) internal view returns (uint256 longX, uint256 shortX, uint256 longY, uint256 shortY) {
        onlySorted(token0, token1);
        uint256 totalLongX;
        uint256 totalShortX;
        uint256 totalLongY;
        uint256 totalShortY;

        (uint256 reserve0Long, uint256 reserve0Short, uint256 reserve1Long, uint256 reserve1Short) =
            getDirectionalBalances(market, token0, token1);

        if (reserve0Long == 0) {
            require(
                amountLong0 >= 1000 && amountShort0 >= 1000 && amountLong1 >= 1000 && amountShort1 >= 1000,
                insufficientAmounts()
            );

            amountLong0 -= 1000;
            amountShort0 -= 1000;
            amountLong1 -= 1000;
            amountShort1 -= 1000;

            reserve0Long = 1000;
            reserve0Short = 1000;
            reserve1Long = 1000;
            reserve1Short = 1000;

            totalLongX = 1000000;
            totalShortX = 1000000;
            totalLongY = 1000000;
            totalShortY = 1000000;
        } else {
            (totalLongX, totalShortX, totalLongY, totalShortY) = getLiquiditySupply(market, token0, token1);
        }

        longX = Math.fullMulDiv(amountLong0, totalLongX, reserve0Long);
        shortX = Math.fullMulDiv(amountShort0, totalShortX, reserve0Short);
        longY = Math.fullMulDiv(amountLong1, totalLongY, reserve1Long);
        shortY = Math.fullMulDiv(amountShort1, totalShortY, reserve1Short);
    }

    function quoteReserve(
        address market,
        address token0,
        address token1,
        uint256 longX,
        uint256 shortX,
        uint256 longY,
        uint256 shortY
    ) internal view returns (uint256 amountLong0, uint256 amountShort0, uint256 amountLong1, uint256 amountShort1) {
        onlySorted(token0, token1);
        (uint256 totalLongX, uint256 totalShortX, uint256 totalLongY, uint256 totalShortY) =
            getLiquiditySupply(market, token0, token1);
        (uint256 reserve0Long, uint256 reserve0Short, uint256 reserve1Long, uint256 reserve1Short) =
            getDirectionalBalances(market, token0, token1);
        if (reserve0Long == 0) revert pairZeroBalance();

        // Calculate fees from LP tokens
        uint256 feeLongX = (longX * 3 + 999) / 1000; // divUp equivalent for 0.3% fee
        uint256 feeShortX = (shortX * 3 + 999) / 1000;
        uint256 feeLongY = (longY * 3 + 999) / 1000;
        uint256 feeShortY = (shortY * 3 + 999) / 1000;

        amountLong0 = Math.fullMulDiv(longX - feeLongX, reserve0Long, totalLongX);
        amountShort0 = Math.fullMulDiv(shortX - feeShortX, reserve0Short, totalShortX);
        amountLong1 = Math.fullMulDiv(longY - feeLongY, reserve1Long, totalLongY);
        amountShort1 = Math.fullMulDiv(shortY - feeShortY, reserve1Short, totalShortY);
    }
}
