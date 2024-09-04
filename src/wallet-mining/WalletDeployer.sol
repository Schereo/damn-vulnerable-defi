// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

/**
 * @notice A contract that allows deployers of Gnosis Safe wallets to be rewarded.
 *         Includes an optional authorization mechanism to ensure only expected accounts
 *         are rewarded for certain deployments.
 */
contract WalletDeployer {
    // Addresses of a Safe factory and copy on this chain
    SafeProxyFactory public immutable cook;
    address public immutable cpy;

    uint256 public constant pay = 1 ether;
    address public immutable chief = msg.sender;
    address public immutable gem;

    address public mom;
    address public hat;

    error Boom();

    // @audit e: Gem is the DVT token
    // @audit e: Cook is the SafeProxyFactory contract
    // @audit e: Cpy is the address of the Safe (singleton) contract
    constructor(address _gem, address _cook, address _cpy) {
        gem = _gem;
        cook = SafeProxyFactory(_cook);
        cpy = _cpy;
    }

    /**
     * @notice Allows the chief to set an authorizer contract.
     */
    // @audit chief is the deployer
    // @audit I don't think this function is exploitable since becoming the deployer (chief) is not possible
    function rule(address _mom) external {
        if (msg.sender != chief || _mom == address(0) || mom != address(0)) {
            revert Boom();
        }
        mom = _mom;
    }

    /**
     * @notice Allows the caller to deploy a new Safe account and receive a payment in return.
     *         If the authorizer is set, the caller must be authorized to execute the deployment
     */
    // @audit e: mom := authorizer contract 
    // @audit e: wat is the initializer of the wallet
    function drop(address aim, bytes memory wat, uint256 num) external returns (bool) {
        // @audit e: Is the authorizer contract set and is the caller not authorized to deploy at the address aim?
        if (mom != address(0) && !can(msg.sender, aim)) {
            return false;
        }

        // @audit e: If the created wallet is not the same as the address aim, return false
        if (address(cook.createProxyWithNonce(cpy, wat, num)) != aim) {
            return false;
        }

        if (IERC20(gem).balanceOf(address(this)) >= pay) {
            IERC20(gem).transfer(msg.sender, pay);
        }
        return true;
    }
    
    /**
     * @notice This function checks whether user u authorized to deploy at address a
     */ 
    function can(address u, address a) public view returns (bool y) {
        assembly {
            let m := sload(0) // Load storage slot 0 and assign to m
            if iszero(extcodesize(m)) { stop() } // Check if m is a contract (codesize > 0)
            let p := mload(0x40) // Load free memory pointer (pointer to where the next free memory is) and assign to p 
            mstore(0x40, add(p, 0x44)) // Update the free memory pointer by adding 0x44 (68 bytes) to it 
            mstore(p, shl(0xe0, 0x4538c4eb)) // Store function selector of this function left shifted by 0xe0 (14 bytes) at p
            mstore(add(p, 0x04), u) // Store u at p + 0x04 (4 bytes) 4-24 bytes are taken by address u
            mstore(add(p, 0x24), a) // Store a at p + 0x24 (36 bytes) 24-44 bytes are taken by address a
            if iszero(staticcall(gas(), m, p, 0x44, p, 0x20)) { stop() } // Call the can function of the authorizer contract with u and a as arguments and store the return value of 20 bytes at p
            y := mload(p)
        }
    }
}
