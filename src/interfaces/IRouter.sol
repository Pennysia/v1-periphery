// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

interface IRouter {
    /// @dev slippage error
    error slippage();

    /// @notice Adds liquidity to a pair
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 dividerX128,
        uint256 minPriceX128, // slippage tolerance
        uint256 maxPriceX128, // slippage tolerance
        address to,
        uint256 deadline
    ) external payable returns (uint256 liquidityLong, uint256 liquidityShort);

    /// @notice Removes liquidity from a pair
    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidityLong,
        uint256 liquidityShort,
        uint256 minPriceX128, // slippage tolerance
        uint256 maxPriceX128, // slippage tolerance
        address to,
        uint256 deadline
    ) external payable returns (uint256 amount0, uint256 amount1);

    // @notice Performs liquidity swap.
    function liquiditySwap(
        address token0,
        address token1,
        bool longToShort,
        uint256 liquidityIn,
        uint256 minPriceX128, // slippage tolerance
        uint256 maxPriceX128, // slippage tolerance
        address to,
        uint256 deadline
    ) external payable returns (uint256 liquidityOut);

    /// @notice Swaps tokens along a path
    function swap(uint256 amountIn, uint256 amountOutMinimum, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256 amountOut);
}
