// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/Router.sol";
import "../src/interfaces/IMarket.sol";
import "../src/interfaces/ILiquidity.sol";
import "../src/interfaces/IPayment.sol";
import "../src/libraries/RouterLibrary.sol";
import "../src/libraries/TransferHelper.sol";

// --- Minimal ERC20 Mock ---
contract ERC20Mock {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "ERC20: transfer amount exceeds balance");
        require(allowance[from][msg.sender] >= amount, "ERC20: transfer amount exceeds allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

// --- IMarket Mock ---
contract MarketMock is IMarket, ILiquidity {
    // For createLiquidity/withdrawLiquidity return values
    uint256 public retLongX;
    uint256 public retShortX;
    uint256 public retLongY;
    uint256 public retShortY;
    uint256 public retAmount0;
    uint256 public retAmount1;
    uint256 public retSwapOut;
    bool public revertCreate;
    bool public revertWithdraw;
    bool public revertSwap;
    bool public revertTransferFrom;
    address public lastTo;
    address[] public lastPath;
    uint256 public lastAmountIn;
    uint256 public lastPoolId;
    uint128 public lastLongX;
    uint128 public lastShortX;
    uint128 public lastLongY;
    uint128 public lastShortY;

    function setCreateLiquidityReturn(uint256 lx, uint256 sx, uint256 ly, uint256 sy) external {
        retLongX = lx; retShortX = sx; retLongY = ly; retShortY = sy;
    }
    function setWithdrawLiquidityReturn(uint256 a0, uint256 a1) external {
        retAmount0 = a0; retAmount1 = a1;
    }
    function setSwapReturn(uint256 out_) external { retSwapOut = out_; }
    function setRevertCreate(bool v) external { revertCreate = v; }
    function setRevertWithdraw(bool v) external { revertWithdraw = v; }
    function setRevertSwap(bool v) external { revertSwap = v; }
    function setRevertTransferFrom(bool v) external { revertTransferFrom = v; }

    // IMarket
    function createLiquidity(address to, address, address, uint256, uint256, uint256, uint256)
        external override returns (uint256, uint256, uint256, uint256, uint256)
    {
        require(!revertCreate, "createLiquidity revert");
        lastTo = to;
        return (0, retLongX, retShortX, retLongY, retShortY);
    }
    function withdrawLiquidity(address to, address, address, uint256, uint256, uint256, uint256)
        external override returns (uint256, uint256, uint256)
    {
        require(!revertWithdraw, "withdrawLiquidity revert");
        lastTo = to;
        return (0, retAmount0, retAmount1);
    }
    function swap(address to, address[] calldata path, uint256 amountIn)
        external override returns (uint256)
    {
        require(!revertSwap, "swap revert");
        lastTo = to;
        lastPath = path;
        lastAmountIn = amountIn;
        return retSwapOut;
    }
    // ILiquidity
    function transferFrom(address to, address, uint256 poolId, uint128 lx, uint128 sx, uint128 ly, uint128 sy) external override {
        require(!revertTransferFrom, "transferFrom revert");
        lastTo = to;
        lastPoolId = poolId;
        lastLongX = lx;
        lastShortX = sx;
        lastLongY = ly;
        lastShortY = sy;
    }
}

contract RouterTest is Test {
    Router router;
    MarketMock market;
    ERC20Mock tokenA;
    ERC20Mock tokenB;
    address user = address(0xBEEF);
    address receiver = address(0xCAFE);

    function setUp() public {
        market = new MarketMock();
        router = new Router(address(market));
        tokenA = new ERC20Mock("TokenA", "TKA");
        tokenB = new ERC20Mock("TokenB", "TKB");
        tokenA.mint(user, 1e24);
        tokenB.mint(user, 1e24);
        vm.deal(user, 1e20);
    }

    // -------- Library Delegation --------
    function testQuoteLiquidityDelegation() public {
        (uint256 lx, uint256 sx, uint256 ly, uint256 sy) = router.quoteLiquidity(address(tokenA), address(tokenB), 1,2,3,4);
        (uint256 lx2, uint256 sx2, uint256 ly2, uint256 sy2) = RouterLibrary.quoteLiquidity(address(market), address(tokenA), address(tokenB), 1,2,3,4);
        assertEq(lx, lx2); assertEq(sx, sx2); assertEq(ly, ly2); assertEq(sy, sy2);
    }
    function testQuoteReserveDelegation() public {
        (uint256 a0, uint256 s0, uint256 a1, uint256 s1) = router.quoteReserve(address(tokenA), address(tokenB), 1,2,3,4);
        (uint256 a02, uint256 s02, uint256 a12, uint256 s12) = RouterLibrary.quoteReserve(address(market), address(tokenA), address(tokenB), 1,2,3,4);
        assertEq(a0, a02); assertEq(s0, s02); assertEq(a1, a12); assertEq(s1, s12);
    }
    function testGetAmountOutDelegation() public {
        uint256 out1 = router.getAmountOut(1000, 1_000_000, 2_000_000);
        uint256 out2 = RouterLibrary.getAmountOut(1000, 1_000_000, 2_000_000);
        assertEq(out1, out2);
    }
    function testGetAmountInDelegation() public {
        uint256 in1 = router.getAmountIn(1000, 1_000_000, 2_000_000);
        uint256 in2 = RouterLibrary.getAmountIn(1000, 1_000_000, 2_000_000);
        assertEq(in1, in2);
    }
    function testGetAmountsOutDelegation() public {
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        uint256[] memory out1 = router.getAmountsOut(1000, path);
        uint256[] memory out2 = RouterLibrary.getAmountsOut(address(market), 1000, path);
        assertEq(out1.length, out2.length);
        for (uint256 i = 0; i < out1.length; i++) assertEq(out1[i], out2[i]);
    }
    function testGetAmountsInDelegation() public {
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        uint256[] memory in1 = router.getAmountsIn(1000, path);
        uint256[] memory in2 = RouterLibrary.getAmountsIn(address(market), 1000, path);
        assertEq(in1.length, in2.length);
        for (uint256 i = 0; i < in1.length; i++) assertEq(in1[i], in2[i]);
    }

    // -------- addLiquidity --------
    function testAddLiquiditySuccess() public {
        market.setCreateLiquidityReturn(10, 20, 30, 40);
        (uint256 lx, uint256 sx, uint256 ly, uint256 sy) = router.addLiquidity(
            address(tokenA), address(tokenB), 100, 200, 300, 400, 10, 20, 30, 40, receiver, block.timestamp + 1 days
        );
        assertEq(lx, 10); assertEq(sx, 20); assertEq(ly, 30); assertEq(sy, 40);
        assertEq(market.lastTo(), receiver);
    }
    function testAddLiquiditySlippageRevert() public {
        market.setCreateLiquidityReturn(1, 2, 3, 4);
        vm.expectRevert();
        router.addLiquidity(address(tokenA), address(tokenB), 100, 200, 300, 400, 10, 20, 30, 40, receiver, block.timestamp + 1 days);
    }
    function testAddLiquidityDeadlineRevert() public {
        market.setCreateLiquidityReturn(10, 20, 30, 40);
        vm.expectRevert();
        router.addLiquidity(address(tokenA), address(tokenB), 100, 200, 300, 400, 10, 20, 30, 40, receiver, block.timestamp - 1);
    }

    // -------- removeLiquidity --------
    function testRemoveLiquiditySuccess() public {
        market.setWithdrawLiquidityReturn(111, 222);
        (uint256 a0, uint256 a1) = router.removeLiquidity(
            address(tokenA), address(tokenB), 10, 20, 30, 40, 100, 200, receiver, block.timestamp + 1 days
        );
        assertEq(a0, 111); assertEq(a1, 222);
        assertEq(market.lastTo(), receiver);
    }
    function testRemoveLiquiditySlippageRevert() public {
        market.setWithdrawLiquidityReturn(1, 2);
        vm.expectRevert();
        router.removeLiquidity(address(tokenA), address(tokenB), 10, 20, 30, 40, 100, 200, receiver, block.timestamp + 1 days);
    }
    function testRemoveLiquidityDeadlineRevert() public {
        market.setWithdrawLiquidityReturn(111, 222);
        vm.expectRevert();
        router.removeLiquidity(address(tokenA), address(tokenB), 10, 20, 30, 40, 100, 200, receiver, block.timestamp - 1);
    }

    // -------- swap --------
    function testSwapSuccess() public {
        market.setSwapReturn(555);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        uint256 out = router.swap(1000, 500, path, receiver, block.timestamp + 1 days);
        assertEq(out, 555);
        assertEq(market.lastTo(), receiver);
        assertEq(market.lastAmountIn(), 1000);
    }
    function testSwapSlippageRevert() public {
        market.setSwapReturn(100);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        vm.expectRevert();
        router.swap(1000, 5000, path, receiver, block.timestamp + 1 days);
    }
    function testSwapDeadlineRevert() public {
        market.setSwapReturn(555);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        vm.expectRevert();
        router.swap(1000, 500, path, receiver, block.timestamp - 1);
    }

    // -------- requestToken --------
    function testRequestTokenNative() public {
        vm.deal(address(router), 1 ether);
        vm.prank(user);
        router.requestToken(receiver, new address[](1), new uint256[](1)); // Should not revert
    }
    function testRequestTokenERC20() public {
        tokenA.mint(address(this), 1000);
        tokenA.approve(address(router), 1000);
        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenA);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;
        router.requestToken(receiver, tokens, amounts);
        // No revert means pass
    }

    // -------- requestLiquidity --------
    function testRequestLiquidity() public {
        router.requestLiquidity(receiver, 42, 1, 2, 3, 4);
        assertEq(market.lastTo(), receiver);
        assertEq(market.lastPoolId(), 42);
        assertEq(market.lastLongX(), 1);
        assertEq(market.lastShortX(), 2);
        assertEq(market.lastLongY(), 3);
        assertEq(market.lastShortY(), 4);
    }

    // -------- Edge Cases --------
    function testAddLiquidityZeroAmounts() public {
        market.setCreateLiquidityReturn(0, 0, 0, 0);
        vm.expectRevert();
        router.addLiquidity(address(tokenA), address(tokenB), 0, 0, 0, 0, 1, 1, 1, 1, receiver, block.timestamp + 1 days);
    }
    function testSwapInvalidPath() public {
        market.setSwapReturn(100);
        address[] memory path = new address[](1); // Invalid path
        path[0] = address(tokenA);
        vm.expectRevert();
        router.swap(1000, 500, path, receiver, block.timestamp + 1 days);
    }
}
