// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import "lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "lib/v3-periphery/contracts/interfaces/IQuoter.sol";

contract Swaps {
    ISwapRouter private immutable SWAPROUTER;
    IQuoter private immutable QUOTER;
    address private immutable DAI;
    address private immutable WETH9;
    address private immutable SWAPTOKEN;
    uint24 private constant fee = 3000;

    event ConvertDaiToEth(address indexed swapper, uint256 indexed amountIn);
    event ConvertDaiToSwapToken(
        address indexed swapper,
        uint256 indexed amountIn
    );
    event ConvertSwapTokenToEth(
        address indexed swapper,
        uint256 indexed amountIn
    );

    constructor(
        ISwapRouter swapRouter_,
        IQuoter quoter_,
        address DAI_,
        address WETH9_,
        address swapToken_
    ) {
        SWAPROUTER = swapRouter_;
        QUOTER = quoter_;
        DAI = DAI_;
        WETH9 = WETH9_;
        SWAPTOKEN = swapToken_;
    }

    receive() external payable {}

    function convertDaiToEth(uint256 amountIn)
        external
        payable
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Cannot convert 0 DAI");

        TransferHelper.safeTransferFrom(
            DAI,
            msg.sender,
            address(this),
            amountIn
        );

        TransferHelper.safeApprove(DAI, address(SWAPROUTER), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: DAI,
                tokenOut: WETH9,
                fee: fee,
                recipient: msg.sender,
                deadline: block.timestamp + 100,
                amountIn: amountIn,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            });

        amountOut = SWAPROUTER.exactInputSingle(params);
        emit ConvertDaiToEth(msg.sender, amountIn);
    }

    function convertDaiToSwapToken(uint256 amountIn)
        external
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Cannot convert 0 DAI");

        TransferHelper.safeTransferFrom(
            DAI,
            msg.sender,
            address(this),
            amountIn
        );

        TransferHelper.safeApprove(DAI, address(SWAPROUTER), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: DAI,
                tokenOut: SWAPTOKEN,
                fee: fee,
                recipient: msg.sender,
                deadline: block.timestamp + 100,
                amountIn: amountIn,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            });

        amountOut = SWAPROUTER.exactInputSingle(params);
        emit ConvertDaiToSwapToken(msg.sender, amountIn);
    }

    function convertSwapTokenToEth(uint256 amountIn)
        external
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Cannot convert 0 SWT");

        TransferHelper.safeTransferFrom(
            SWAPTOKEN,
            msg.sender,
            address(this),
            amountIn
        );

        TransferHelper.safeApprove(SWAPTOKEN, address(SWAPROUTER), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: SWAPTOKEN,
                tokenOut: WETH9,
                fee: fee,
                recipient: msg.sender,
                deadline: block.timestamp + 100,
                amountIn: amountIn,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            });

        amountOut = SWAPROUTER.exactInputSingle(params);
        emit ConvertSwapTokenToEth(msg.sender, amountIn);
    }

    function estimateDaiforEth(uint256 ethAmountOut)
        external
        payable
        returns (uint256)
    {
        return QUOTER.quoteExactOutputSingle(DAI, WETH9, fee, ethAmountOut, 0);
    }

    function estimateDaiForSwapToken(uint256 tokenAmountOut)
        external
        payable
        returns (uint256)
    {
        return
            QUOTER.quoteExactOutputSingle(
                DAI,
                SWAPTOKEN,
                fee,
                tokenAmountOut,
                0
            );
    }

    function estimateSwapTokenForEth(uint256 ethAmountOut)
        external
        payable
        returns (uint256)
    {
        return
            QUOTER.quoteExactOutputSingle(
                SWAPTOKEN,
                WETH9,
                fee,
                ethAmountOut,
                0
            );
    }
}
