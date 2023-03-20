// SPDX-License-Identifier: GPL-2.0

pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import "lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "lib/v3-periphery/contracts/interfaces/IPoolInitializer.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "lib/v3-core/contracts/libraries/TickMath.sol";
import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import "lib/v3-periphery/contracts/base/LiquidityManagement.sol";

contract LiquidityProvider {
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    mapping(uint256 => Deposit) public deposits;

    constructor(INonfungiblePositionManager _nonfungiblePositionManager) {
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

    event PositionMinted(
        address indexed positionManager,
        address indexed token0,
        address indexed token1,
        uint256 amount0Desired,
        uint256 amount1Desired
    );

    function createPool(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external {
        nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            token0,
            token1,
            fee,
            sqrtPriceX96
        );
    }

    function provideLiquidity(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        external
        returns (
            uint256 tokenId,
            uint256 amount0Deposited,
            uint256 amount1Deposited
        )
    {
        TransferHelper.safeTransferFrom(
            token0,
            msg.sender,
            address(this),
            amount0Desired
        );

        TransferHelper.safeTransferFrom(
            token1,
            msg.sender,
            address(this),
            amount1Desired
        );

        // Approve the position manager
        TransferHelper.safeApprove(
            token0,
            address(nonfungiblePositionManager),
            amount0Desired
        );
        TransferHelper.safeApprove(
            token1,
            address(nonfungiblePositionManager),
            amount1Desired
        );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: msg.sender,
                deadline: block.timestamp + 60
            });

        (
            tokenId,
            ,
            amount0Deposited,
            amount1Deposited
        ) = nonfungiblePositionManager.mint(params);

        _createDeposit(msg.sender, tokenId);

        // Remove allowance and refund
        if (amount0Deposited < amount0Desired) {
            TransferHelper.safeApprove(
                token0,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund0 = amount0Desired - amount0Deposited;
            TransferHelper.safeTransfer(token0, msg.sender, refund0);
        }

        if (amount1Deposited < amount1Desired) {
            TransferHelper.safeApprove(
                token1,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund1 = amount1Desired - amount1Deposited;
            TransferHelper.safeTransfer(token1, msg.sender, refund1);
        }

        emit PositionMinted(
            address(this),
            token0,
            token1,
            amount0Desired,
            amount1Desired
        );
    }

    function _createDeposit(address owner, uint256 tokenId) internal {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(tokenId);

        deposits[tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1
        });
    }
}
