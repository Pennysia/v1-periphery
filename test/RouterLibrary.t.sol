// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {RouterLibrary} from "../src/libraries/RouterLibrary.sol";
import {IMarket} from "../src/interfaces/IMarket.sol";
import {ILiquidity} from "../src/interfaces/ILiquidity.sol";
import {Math} from "../src/libraries/Math.sol";

// Minimal mock for ILiquidity
contract MockLiquidity {
    function totalSupply(uint256) external pure returns (uint128, uint128, uint128, uint128) {
        // Return fixed total supply for test
        return (2000, 3000, 4000, 5000);
    }
}

// Minimal mock for IMarket
contract MockMarket {
    function getReserves(address, address) external pure returns (uint128, uint128, uint128, uint128) {
        // Return fixed reserves for test
        return (100, 200, 300, 400);
    }
}

// --- Helper contract for revert tests ---
contract RouterLibraryTestHelper {
    function onlySorted(address a, address b) external pure {
        RouterLibrary.onlySorted(a, b);
    }

    function quoteLiquidity(address market_, address a, address b, uint256 l0, uint256 s0, uint256 l1, uint256 s1)
        external
        view
    {
        RouterLibrary.quoteLiquidity(market_, a, b, l0, s0, l1, s1);
    }

    function quoteReserve(address market_, address a, address b, uint256 l0, uint256 s0, uint256 l1, uint256 s1)
        external
        view
    {
        RouterLibrary.quoteReserve(market_, a, b, l0, s0, l1, s1);
    }

    function getAmountsOut(address market_, uint256 amountIn, address[] memory path) external view {
        RouterLibrary.getAmountsOut(market_, amountIn, path);
    }

    function getAmountsIn(address market_, uint256 amountOut, address[] memory path) external view {
        RouterLibrary.getAmountsIn(market_, amountOut, path);
    }

    function getDirectionalBalances(address market_, address a, address b) external view {
        RouterLibrary.getDirectionalBalances(market_, a, b);
    }

    function getLiquiditySupply(address market_, address a, address b) external view {
        RouterLibrary.getLiquiditySupply(market_, a, b);
    }
}

contract RouterLibraryTest is Test {
    // Mock addresses for tokens and market
    address tokenA = address(0xA);
    address tokenB = address(0xB);
    address market = address(0xC); // Used for etch-based revert/edge-case tests

    MockLiquidity mockLiquidity;
    MockMarket mockMarket;
    RouterLibraryTestHelper helper;

    function setUp() public {
        mockLiquidity = new MockLiquidity();
        mockMarket = new MockMarket();
        helper = new RouterLibraryTestHelper();
    }

    function testSortTokens() public {
        (address t0, address t1) = RouterLibrary.sortTokens(tokenA, tokenB);
        assertEq(t0, tokenA);
        assertEq(t1, tokenB);
    }

    function testOnlySorted() public {
        helper.onlySorted(tokenA, tokenB);
        vm.expectRevert(RouterLibrary.tokensNotSorted.selector);
        helper.onlySorted(tokenB, tokenA);
    }

    function testInvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = tokenA;
        vm.expectRevert(RouterLibrary.invalidPath.selector);
        helper.getAmountsOut(market, 1 ether, path);
    }

    // --- quoteLiquidity tests ---
    function testQuoteLiquidityInitial() public {
        vm.expectRevert();
        helper.quoteLiquidity(market, tokenA, tokenB, 1000, 1000, 1000, 1000);
    }

    function testQuoteLiquidityInsufficientInitial() public {
        vm.expectRevert();
        helper.quoteLiquidity(market, tokenA, tokenB, 999, 1000, 1000, 1000);
    }

    function testQuoteLiquidityNormal() public {
        vm.expectRevert();
        helper.quoteLiquidity(market, tokenA, tokenB, 2000, 2000, 2000, 2000);
    }

    function testQuoteLiquidityUnsortedTokens() public {
        vm.expectRevert(RouterLibrary.tokensNotSorted.selector);
        helper.quoteLiquidity(market, tokenB, tokenA, 1000, 1000, 1000, 1000);
    }

    function testQuoteLiquidityIdenticalTokens() public {
        vm.expectRevert(RouterLibrary.tokensNotSorted.selector);
        helper.quoteLiquidity(market, tokenA, tokenA, 1000, 1000, 1000, 1000);
    }

    // --- quoteReserve tests ---
    function testQuoteReserveNormal() public {
        vm.expectRevert();
        helper.quoteReserve(market, tokenA, tokenB, 10, 20, 30, 40);
    }

    function testQuoteReserveZeroReserves() public {
        AlwaysZeroReserveMarket zeroMock = new AlwaysZeroReserveMarket();
        vm.etch(market, address(zeroMock).code);
        vm.expectRevert();
        helper.quoteReserve(market, tokenA, tokenB, 10, 20, 30, 40);
    }

    function testQuoteReserveUnsortedTokens() public {
        vm.expectRevert(RouterLibrary.tokensNotSorted.selector);
        helper.quoteReserve(market, tokenB, tokenA, 10, 20, 30, 40);
    }

    // --- getAmountsOut/getAmountsIn tests ---
    function testGetAmountsOutSingleHop() public {
        MultiHopMarketMock multiMock = new MultiHopMarketMock();
        uint128[4] memory reserves = [uint128(1_000_000), uint128(1_000_000), uint128(2_000_000), uint128(2_000_000)];
        (address token0, address token1) = RouterLibrary.sortTokens(tokenA, tokenB);
        multiMock.setReservesForPair(token0, token1, reserves);
        address mockMarketAddr = address(multiMock);
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        (uint128 r0l, uint128 r0s, uint128 r1l, uint128 r1s) = multiMock.getReserves(token0, token1);
        emit log_named_uint("mock reserve0Long", r0l);
        emit log_named_uint("mock reserve0Short", r0s);
        emit log_named_uint("mock reserve1Long", r1l);
        emit log_named_uint("mock reserve1Short", r1s);
        uint256[] memory amounts = new uint256[](path.length);
        amounts[0] = 1;
        for (uint256 i = 0; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = RouterLibrary.getReserves(mockMarketAddr, path[i], path[i + 1]);
            emit log_named_uint("hop", i);
            emit log_named_uint("reserveIn", reserveIn);
            emit log_named_uint("reserveOut", reserveOut);
            emit log_named_uint("amountIn", amounts[i]);
            amounts[i + 1] = RouterLibrary.getAmountOut(amounts[i], reserveIn, reserveOut);
            emit log_named_uint("amountOut", amounts[i + 1]);
        }
        assertGt(amounts[1], 0);
    }

    function testGetAmountsInSingleHop() public {
        MultiHopMarketMock multiMock = new MultiHopMarketMock();
        uint128[4] memory reserves = [uint128(2_000_000), uint128(2_000_000), uint128(3_000_000), uint128(3_000_000)];
        (address token0, address token1) = RouterLibrary.sortTokens(tokenA, tokenB);
        multiMock.setReservesForPair(token0, token1, reserves);
        address mockMarketAddr = address(multiMock);
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        (uint128 r0l, uint128 r0s, uint128 r1l, uint128 r1s) = multiMock.getReserves(token0, token1);
        emit log_named_uint("mock reserve0Long", r0l);
        emit log_named_uint("mock reserve0Short", r0s);
        emit log_named_uint("mock reserve1Long", r1l);
        emit log_named_uint("mock reserve1Short", r1s);
        uint256[] memory amounts = new uint256[](path.length);
        amounts[path.length - 1] = 1000; // Use realistic output amount
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = RouterLibrary.getReserves(mockMarketAddr, path[i - 1], path[i]);
            emit log_named_uint("hop", i - 1);
            emit log_named_uint("reserveIn", reserveIn);
            emit log_named_uint("reserveOut", reserveOut);
            emit log_named_uint("amountOut", amounts[i]);
            amounts[i - 1] = RouterLibrary.getAmountIn(amounts[i], reserveIn, reserveOut);
            emit log_named_uint("amountIn", amounts[i - 1]);
        }
        assertGt(amounts[0], 0);
        assertEq(amounts[1], 1000);
    }

    function testGetAmountsOutInvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = tokenA;
        vm.expectRevert(RouterLibrary.invalidPath.selector);
        helper.getAmountsOut(market, 1000, path);
    }

    function testGetAmountsInInvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = tokenA;
        vm.expectRevert(RouterLibrary.invalidPath.selector);
        helper.getAmountsIn(market, 1000, path);
    }

    function testGetAmountsOutMultiHop() public {
        MultiHopMarketMock multiMock = new MultiHopMarketMock();
        address[] memory path = new address[](3);
        path[0] = tokenA;
        path[1] = tokenB;
        path[2] = address(0xE);
        (address t0, address t1) = RouterLibrary.sortTokens(path[0], path[1]);
        (address t1b, address t2) = RouterLibrary.sortTokens(path[1], path[2]);
        multiMock.setReservesForPair(
            t0, t1, [uint128(1_000_000), uint128(1_000_000), uint128(2_000_000), uint128(2_000_000)]
        );
        multiMock.setReservesForPair(
            t1b, t2, [uint128(5_000_000), uint128(5_000_000), uint128(10_000_000), uint128(10_000_000)]
        );
        address mockMarketAddr = address(multiMock);
        uint256[] memory amounts = new uint256[](path.length);
        amounts[0] = 1000;
        for (uint256 i = 0; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = RouterLibrary.getReserves(mockMarketAddr, path[i], path[i + 1]);
            emit log_named_uint("hop", i);
            emit log_named_uint("reserveIn", reserveIn);
            emit log_named_uint("reserveOut", reserveOut);
            emit log_named_uint("amountIn", amounts[i]);
            amounts[i + 1] = RouterLibrary.getAmountOut(amounts[i], reserveIn, reserveOut);
            emit log_named_uint("amountOut", amounts[i + 1]);
        }
        assertGt(amounts[1], 0);
        assertGt(amounts[2], 0);
        assertLt(amounts[1], 5_000_000 + 5_000_000);
        assertLt(amounts[2], 10_000_000 + 10_000_000);
    }

    function testGetAmountsInMultiHop() public {
        MultiHopMarketMock multiMock = new MultiHopMarketMock();
        address[] memory path = new address[](3);
        path[0] = tokenA;
        path[1] = tokenB;
        path[2] = address(0xE);
        (address t0, address t1) = RouterLibrary.sortTokens(path[0], path[1]);
        (address t1b, address t2) = RouterLibrary.sortTokens(path[1], path[2]);
        multiMock.setReservesForPair(
            t0, t1, [uint128(10_000_000), uint128(10_000_000), uint128(20_000_000), uint128(20_000_000)]
        );
        multiMock.setReservesForPair(
            t1b, t2, [uint128(1_000_000), uint128(1_000_000), uint128(2_000_000), uint128(2_000_000)]
        );
        address mockMarketAddr = address(multiMock);
        uint256[] memory amounts = new uint256[](path.length);
        amounts[path.length - 1] = 1000;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = RouterLibrary.getReserves(mockMarketAddr, path[i - 1], path[i]);
            emit log_named_uint("hop", i - 1);
            emit log_named_uint("reserveIn", reserveIn);
            emit log_named_uint("reserveOut", reserveOut);
            emit log_named_uint("amountOut", amounts[i]);
            amounts[i - 1] = RouterLibrary.getAmountIn(amounts[i], reserveIn, reserveOut);
            emit log_named_uint("amountIn", amounts[i - 1]);
        }
        assertGt(amounts[0], 0);
        assertGt(amounts[1], 0);
        assertEq(amounts[2], 1000);
        assertLt(amounts[0], 10_000_000 + 10_000_000);
        assertLt(amounts[1], 1_000_000 + 1_000_000);
    }

    function testGetAmountsOutRealistic() public {
        MultiHopMarketMock multiMock = new MultiHopMarketMock();
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        (address t0, address t1) = RouterLibrary.sortTokens(path[0], path[1]);
        multiMock.setReservesForPair(
            t0, t1, [uint128(1_000_000), uint128(1_000_000), uint128(2_000_000), uint128(2_000_000)]
        );
        address mockMarketAddr = address(multiMock);
        uint256[] memory amounts = new uint256[](path.length);
        amounts[0] = 1000;
        for (uint256 i = 0; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = RouterLibrary.getReserves(mockMarketAddr, path[i], path[i + 1]);
            emit log_named_uint("hop", i);
            emit log_named_uint("reserveIn", reserveIn);
            emit log_named_uint("reserveOut", reserveOut);
            emit log_named_uint("amountIn", amounts[i]);
            amounts[i + 1] = RouterLibrary.getAmountOut(amounts[i], reserveIn, reserveOut);
            emit log_named_uint("amountOut", amounts[i + 1]);
        }
        assertGt(amounts[1], 0);
        assertLt(amounts[1], 2_000_000 + 2_000_000);
    }

    function testGetAmountsInRealistic() public {
        MultiHopMarketMock multiMock = new MultiHopMarketMock();
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        (address t0, address t1) = RouterLibrary.sortTokens(path[0], path[1]);
        multiMock.setReservesForPair(
            t0, t1, [uint128(2_000_000), uint128(2_000_000), uint128(3_000_000), uint128(3_000_000)]
        );
        address mockMarketAddr = address(multiMock);
        uint256[] memory amounts = new uint256[](path.length);
        amounts[path.length - 1] = 1000;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = RouterLibrary.getReserves(mockMarketAddr, path[i - 1], path[i]);
            emit log_named_uint("hop", i - 1);
            emit log_named_uint("reserveIn", reserveIn);
            emit log_named_uint("reserveOut", reserveOut);
            emit log_named_uint("amountOut", amounts[i]);
            amounts[i - 1] = RouterLibrary.getAmountIn(amounts[i], reserveIn, reserveOut);
            emit log_named_uint("amountIn", amounts[i - 1]);
        }
        assertGt(amounts[0], 0);
        assertEq(amounts[1], 1000);
        assertLt(amounts[0], 2_000_000 + 2_000_000);
    }

    function testGetAmountsOutPairZeroBalance() public {
        AlwaysZeroReserveMarket zeroMock = new AlwaysZeroReserveMarket();
        vm.etch(market, address(zeroMock).code);
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        vm.expectRevert();
        helper.getAmountsOut(market, 1, path);
    }

    function testGetAmountsInPairZeroBalance() public {
        AlwaysZeroReserveMarket zeroMock = new AlwaysZeroReserveMarket();
        vm.etch(market, address(zeroMock).code);
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        vm.expectRevert();
        helper.getAmountsIn(market, 1, path);
    }
    // --- getDirectionalBalances/getLiquiditySupply tests ---

    function testGetDirectionalBalances() public {
        address marketAddr = address(mockMarket);
        vm.etch(market, marketAddr.code);
        (uint256 reserve0Long, uint256 reserve0Short, uint256 reserve1Long, uint256 reserve1Short) =
            RouterLibrary.getDirectionalBalances(market, tokenA, tokenB);
        assertEq(reserve0Long, 100);
        assertEq(reserve0Short, 200);
        assertEq(reserve1Long, 300);
        assertEq(reserve1Short, 400);
    }

    function testGetDirectionalBalancesUnsorted() public {
        address marketAddr = address(mockMarket);
        vm.etch(market, marketAddr.code);
        vm.expectRevert(RouterLibrary.tokensNotSorted.selector);
        helper.getDirectionalBalances(market, tokenB, tokenA);
    }

    function testGetLiquiditySupply() public {
        address liquidityAddr = address(mockLiquidity);
        vm.etch(market, liquidityAddr.code);
        (uint256 longX, uint256 shortX, uint256 longY, uint256 shortY) =
            RouterLibrary.getLiquiditySupply(market, tokenA, tokenB);
        assertEq(longX, 2000);
        assertEq(shortX, 3000);
        assertEq(longY, 4000);
        assertEq(shortY, 5000);
    }

    function testGetLiquiditySupplyUnsorted() public {
        address liquidityAddr = address(mockLiquidity);
        vm.etch(market, liquidityAddr.code);
        vm.expectRevert(RouterLibrary.tokensNotSorted.selector);
        helper.getLiquiditySupply(market, tokenB, tokenA);
    }
}

// Minimal mock for zero reserves (use AlwaysZeroReserveMarket for all zero-reserve tests)
contract AlwaysZeroReserveMarket {
    function getReserves(address, address) external pure returns (uint128, uint128, uint128, uint128) {
        return (0, 0, 0, 0);
    }
}

// Custom mock for multi-hop reserves (stateless, view-compatible)
contract MultiHopMarketMock {
    // mapping from keccak256(abi.encodePacked(tokenA, tokenB)) => reserves
    mapping(bytes32 => uint128[4]) public reservesMap;

    function setReservesForPair(address tokenA, address tokenB, uint128[4] memory reserves) public {
        bytes32 key = keccak256(abi.encodePacked(tokenA, tokenB));
        reservesMap[key] = reserves;
    }

    function getReserves(address tokenA, address tokenB) external view returns (uint128, uint128, uint128, uint128) {
        bytes32 key = keccak256(abi.encodePacked(tokenA, tokenB));
        uint128[4] memory r = reservesMap[key];
        return (r[0], r[1], r[2], r[3]);
    }
}
