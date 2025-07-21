// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

interface IRouter {
    /// @dev The slippage check has failed.
    error slippage();
    /// @dev check for address validation
    error forbidden();

    /// @notice Quotes the amount of LP tokens to be minted for given amounts
    function quoteLiquidity(
        address token0,
        address token1,
        uint256 amountLong0,
        uint256 amountShort0,
        uint256 amountLong1,
        uint256 amountShort1
    ) external view returns (uint256 longX, uint256 shortX, uint256 longY, uint256 shortY);

    /// @notice Quotes the amount of tokens needed for given LP token amounts
    function quoteReserve(address token0, address token1, uint256 longX, uint256 shortX, uint256 longY, uint256 shortY)
        external
        view
        returns (uint256 amountLong0, uint256 amountShort0, uint256 amountLong1, uint256 amountShort1);

    /// @notice Returns the output amount for a given input and reserves
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountOut);

    /// @notice Returns the input amount required for a given output and reserves
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountIn);

    /// @notice Returns the output amounts for a path and input amount
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    /// @notice Returns the input amounts for a path and output amount
    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    /// @notice Sweeps any native ETH held by the router to the specified address
    function sweepNative(address to) external;

    /// @notice Adds liquidity to a pair
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
    ) external payable returns (uint256 longX, uint256 shortX, uint256 longY, uint256 shortY);

    /// @notice Removes liquidity from a pair
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
    ) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice Swaps tokens along a path
    function swap(uint256 amountIn, uint256 amountOutMinimum, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256 amountOut);
}
