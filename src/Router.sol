// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.28;

import {RouterLibrary} from "./libraries/RouterLibrary.sol";

contract Router {
    address public immutable market;

    constructor(address _market) {
        market = _market;
    }

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
}
