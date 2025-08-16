// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {IMarket} from "../interfaces/IMarket.sol";

library RouterLibrary {
    error identicalTokens();
    error pairZeroBalance();
    error tokensNotSorted();
    error insufficientAmounts();

    function onlySorted(address tokenA, address tokenB) internal pure {
        require(tokenA < tokenB, tokensNotSorted());
    }

    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, identicalTokens());
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
    }

    function computePairId(
        address token0,
        address token1
    ) internal pure returns (uint256 pairId) {
        pairId = uint256(keccak256(abi.encodePacked(token0, token1)));
    }

    function getReserves(
        address market,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        (
            uint256 reserve0Long,
            uint256 reserve0Short,
            uint256 reserve1Long,
            uint256 reserve1Short
        ) = getDirectionalBalances(market, token0, token1);

        uint256 reserve0 = reserve0Long + reserve0Short;
        uint256 reserve1 = reserve1Long + reserve1Short;
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    // --------- Get Amounts ---------

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
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

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, insufficientAmounts());
        require(reserveIn > 0 && reserveOut > 0, pairZeroBalance());
        uint256 amountOutWithFee = ((amountOut * 1003 + 999) / 1000); // divUp equivalent
        uint256 newReserveOut = reserveOut - amountOutWithFee;
        uint256 newReserveIn = (reserveIn * reserveOut) / newReserveOut;
        amountIn = newReserveIn - reserveIn;
    }

    function getDirectionalBalances(
        address market,
        address token0,
        address token1
    )
        internal
        view
        returns (
            uint256 reserve0Long,
            uint256 reserve0Short,
            uint256 reserve1Long,
            uint256 reserve1Short
        )
    {
        onlySorted(token0, token1);
        (reserve0Long, reserve0Short, reserve1Long, reserve1Short) = IMarket(
            market
        ).getReserves(token0, token1);
    }

    function quoteLiquidity(
        address market,
        address token0,
        address token1,
        uint256 amountLong0,
        uint256 amountShort0,
        uint256 amountLong1,
        uint256 amountShort1
    )
        internal
        view
        returns (uint256 longX, uint256 shortX, uint256 longY, uint256 shortY)
    {
        //TODO: complete this, must check sorting of token0 and token1
    }
}
