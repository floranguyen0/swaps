// SPDX-License-Identifier: GPL-2.0
pragma solidity >=0.6.0 <0.8.0;

import "forge-std/Test.sol";
import "lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "lib/v3-periphery/contracts/interfaces/IQuoter.sol";
import "lib/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../src/Swaps.sol";
import "../src/tokens/SwapToken.sol";
import "../src/tokens/dai.sol";
import "../src/LiquidityProvider.sol";
import "./libraries/Sqrt.sol";
import "./libraries/Utils.sol";

contract SwapsTest is Test {
    uint24 public constant fee = 3000;
    IWETH9 public constant WETH9 =
        IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    INonfungiblePositionManager public constant nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    IUniswapV3Factory public constant uniswapV3Factory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    ISwapRouter public constant swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IQuoter public constant quoter =
        IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    Dai public DAI;
    SwapToken public swapToken;
    LiquidityProvider public liquidityProvider;
    Swaps public swaps;

    event PositionMinted(
        address indexed positionManager,
        address indexed token0,
        address indexed token1,
        uint256 amount0Desired,
        uint256 amount1Desired
    );

    event ConvertDaiToEth(address indexed swapper, uint256 indexed amountIn);
    event ConvertDaiToSwapToken(
        address indexed swapper,
        uint256 indexed amountIn
    );
    event ConvertSwapTokenToEth(
        address indexed swapper,
        uint256 indexed amountIn
    );

    function setUp() public {
        // set up contracts
        swapToken = new SwapToken();
        DAI = new Dai(1);
        liquidityProvider = new LiquidityProvider(nonfungiblePositionManager);
        swaps = new Swaps(
            swapRouter,
            quoter,
            address(DAI),
            address(WETH9),
            address(swapToken)
        );

        // get DAI and WETH9 to the deployer
        DAI.mint(deployer, 100_000e18);
        vm.deal(deployer, 100_000 ether);
        WETH9.deposit{value: 10_000e18}();
    }

    function testConvertDaiToEth(uint256 swappedAmount) public {
        vm.assume(swappedAmount > 10 && swappedAmount < 1000e18);

        _liquiditySetUp(liquidityProvider, address(DAI), address(WETH9), 1500);

        uint256 daiBalance = DAI.balanceOf(address(this));
        uint256 Weth9Balance = WETH9.balanceOf(address(this));

        DAI.approve(address(swaps), swappedAmount);
        vm.expectEmit(true, true, true, true);
        emit ConvertDaiToEth(address(this), swappedAmount);
        uint256 swapEthAmount = swaps.convertDaiToEth(swappedAmount);
        console2.log(swapEthAmount);

        uint256 daiBalanceUpdated = DAI.balanceOf(address(this));
        uint256 Weth9BalanceUpdated = WETH9.balanceOf(address(this));

        assertEq(daiBalanceUpdated, daiBalance - swappedAmount);
        assertEq(Weth9BalanceUpdated, Weth9Balance + swapEthAmount);
    }

    function testConvertDaitoSwapToken(uint256 swappedAmount) public {
        vm.assume(swappedAmount > 10 && swappedAmount < 1000e18);

        _liquiditySetUp(liquidityProvider, address(DAI), address(swapToken), 1);

        uint256 daiBalance = DAI.balanceOf(address(this));
        uint256 swapTokenBalance = swapToken.balanceOf(address(this));

        DAI.approve(address(swaps), swappedAmount);
        vm.expectEmit(true, true, true, true);
        emit ConvertDaiToSwapToken(address(this), swappedAmount);
        uint256 swapTokenAmount = swaps.convertDaiToSwapToken(swappedAmount);

        uint256 daiBalanceUpdated = DAI.balanceOf(address(this));
        uint256 swapTokenBalanceUpdated = swapToken.balanceOf(address(this));

        assertEq(daiBalanceUpdated, daiBalance - swappedAmount);
        assertEq(swapTokenBalanceUpdated, swapTokenBalance + swapTokenAmount);
    }

    function testConvertSwapTokenToEth(uint256 swappedAmount) public {
        vm.assume(swappedAmount > 10 && swappedAmount < 1000e18);

        _liquiditySetUp(
            liquidityProvider,
            address(swapToken),
            address(WETH9),
            1500
        );
        uint256 swapTokenBalance = swapToken.balanceOf(address(this));
        uint256 Weth9Balance = WETH9.balanceOf(address(this));

        swapToken.approve(address(swaps), swappedAmount);
        vm.expectEmit(true, true, true, true);
        emit ConvertSwapTokenToEth(address(this), swappedAmount);
        uint256 Weth9Amount = swaps.convertSwapTokenToEth(swappedAmount);

        uint256 Weth9BalanceUpdated = WETH9.balanceOf(address(this));
        uint256 swapTokenBalanceUpdated = swapToken.balanceOf(address(this));

        assertEq(swapTokenBalanceUpdated, swapTokenBalance - swappedAmount);
        assertEq(Weth9BalanceUpdated, Weth9Balance + Weth9Amount);
    }

    function _liquiditySetUp(
        LiquidityProvider liquidityProvider,
        address token0,
        address token1,
        uint16 price
    ) internal {
        // sort addresses
        // Note: The addresses were sorted beforehand to avoid price change to a floating point number
        // Consider to test the contract on Hardhat to enable type(price) == float
        address[2] memory tokens = [token0, token1];
        if (tokens[1] < tokens[0])
            (tokens[1], tokens[0]) = (tokens[0], tokens[1]);

        // Change price based on token address positions
        // Note: The addresses were sorted beforehand to avoid price change to a floating point numbers
        // Consider to test the contract on Hardhat to enable type(price) == float
        if (tokens[0] != token0) {
            price = 1 / price;
        }

        liquidityProvider.createPool(
            tokens[0],
            tokens[1],
            fee,
            uint160(Sqrt.calculateSqrt(price * 2**192))
        );

        address deployedPoolAddress = uniswapV3Factory.getPool(
            tokens[0],
            tokens[1],
            fee
        );

        IUniswapV3Pool deployedPoolContract = IUniswapV3Pool(
            deployedPoolAddress
        );

        (, int24 tick, , , , , ) = deployedPoolContract.slot0();
        int24 tickSpacing = deployedPoolContract.tickSpacing();
        int24 nearestUsableTick = Utils.nearestUsableTick(tick, tickSpacing);

        // provide liquidity
        SwapToken(tokens[0]).approve(address(liquidityProvider), 1000e18);
        SwapToken(tokens[1]).approve(address(liquidityProvider), 1000e18);

        vm.expectEmit(true, true, true, true);
        emit PositionMinted(
            address(liquidityProvider),
            tokens[0],
            tokens[1],
            1000e18,
            1000e18
        );
        (
            uint256 tokenId,
            uint256 amount0Deposited,
            uint256 amount1Deposited
        ) = liquidityProvider.provideLiquidity(
                tokens[0],
                tokens[1],
                fee,
                nearestUsableTick - tickSpacing * 10,
                nearestUsableTick + tickSpacing * 10,
                1000e18,
                1000e18
            );

        // assertEq(
        //     liquidityProvider.deposits(tokenId),
        //     (address(this), 2000e18, tokens[0], tokens[1])
        // );
    }
}
