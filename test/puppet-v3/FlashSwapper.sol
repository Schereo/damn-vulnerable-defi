//SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import {console} from "forge-std/Console.sol";

import {PuppetV3Pool} from "../../src/puppet-v3/PuppetV3Pool.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {INonfungiblePositionManager} from "../../src/puppet-v3/INonfungiblePositionManager.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

contract FlashSwapper is IUniswapV3FlashCallback {
    IUniswapV3Pool public immutable pool;
    PuppetV3Pool public immutable puppetPool;
    DamnValuableToken public immutable dvtToken;
    WETH public immutable wethToken;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    constructor(
        IUniswapV3Pool _pool,
        PuppetV3Pool _puppetPool,
        DamnValuableToken _dvtToken,
        WETH _wethToken,
        INonfungiblePositionManager _nonfungiblePositionManager
    ) {
        pool = _pool;
        puppetPool = _puppetPool;
        dvtToken = _dvtToken;
        wethToken = _wethToken;
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

    function executeFlashSwap(uint256 amount0, uint256 amount1) external {
        bytes memory data = abi.encode(amount0 + amount1);
        pool.flash(address(this), amount0, amount1, data);
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        require(msg.sender == address(pool), "Not authorized");

        uint256 flashLoanAmount = abi.decode(data, (uint256));

        // Approve NonfungiblePositionManager to spend DVT
        dvtToken.approve(address(nonfungiblePositionManager), flashLoanAmount);

        // Get current tick from the pool
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        int24 currentTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        // Determine token order
        (address token0, address token1) = _determineTokenOrder();

        // Mint new position
        (, , uint amount0, uint amount1) = _mintNewPosition(
            token0,
            token1,
            currentTick,
            flashLoanAmount
        );

        uint256 wethDepositRequiredBefore = puppetPool
            .calculateDepositOfWETHRequired(100e18);

        console.log("wethDepositRequiredAfter: ", wethDepositRequiredBefore);

        // Handle any unused DVT (if any)
        uint unusedDVT = flashLoanAmount -
            (address(dvtToken) == token0 ? amount0 : amount1);
        if (unusedDVT > 0) {
            dvtToken.transfer(address(pool), unusedDVT);
        }

        // Repay flash loan
        dvtToken.transfer(
            address(pool),
            flashLoanAmount + (address(dvtToken) == token0 ? fee0 : fee1)
        );

        // Repay the pool
        if (fee0 > 0) {
            IERC20(pool.token0()).transfer(address(pool), amount0 + fee0);
        }
        if (fee1 > 0) {
            IERC20(pool.token1()).transfer(address(pool), amount1 + fee1);
        }
    }

    function _mintNewPosition(
        address token0,
        address token1,
        int24 currentTick,
        uint256 flashLoanAmount
    ) private returns (uint, uint128, uint, uint) {
        int24 tickLower = currentTick - 1000;
        int24 tickUpper = currentTick + 1000;

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: pool.fee(),
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: address(dvtToken) == token0
                    ? flashLoanAmount
                    : 0,
                amount1Desired: address(dvtToken) == token1
                    ? flashLoanAmount
                    : 0,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        return nonfungiblePositionManager.mint(params);
    }

    function _determineTokenOrder() private view returns (address, address) {
        return
            address(dvtToken) < address(wethToken)
                ? (address(dvtToken), address(wethToken))
                : (address(wethToken), address(dvtToken));
    }
}
