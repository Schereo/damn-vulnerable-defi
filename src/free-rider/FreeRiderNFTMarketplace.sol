// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DamnValuableNFT} from "../DamnValuableNFT.sol";

contract FreeRiderNFTMarketplace is ReentrancyGuard {
    using Address for address payable;

    DamnValuableNFT public token;
    uint256 public offersCount;

    // tokenId -> price
    mapping(uint256 => uint256) private offers;

    event NFTOffered(address indexed offerer, uint256 tokenId, uint256 price);
    event NFTBought(address indexed buyer, uint256 tokenId, uint256 price);

    error InvalidPricesAmount();
    error InvalidTokensAmount();
    error InvalidPrice();
    error CallerNotOwner(uint256 tokenId);
    error InvalidApproval();
    error TokenNotOffered(uint256 tokenId);
    error InsufficientPayment();

    constructor(uint256 amount) payable {
        DamnValuableNFT _token = new DamnValuableNFT();
        _token.renounceOwnership();
        for (uint256 i = 0; i < amount;) {
            _token.safeMint(msg.sender);
            unchecked {
                ++i;
            }
        }
        token = _token;
    }

    function offerMany(uint256[] calldata tokenIds, uint256[] calldata prices) external nonReentrant {
        uint256 amount = tokenIds.length;
        if (amount == 0) {
            revert InvalidTokensAmount();
        }

        if (amount != prices.length) {
            revert InvalidPricesAmount();
        }

        for (uint256 i = 0; i < amount; ++i) {
            unchecked {
                _offerOne(tokenIds[i], prices[i]);
            }
        }
    }

    function _offerOne(uint256 tokenId, uint256 price) private {
        DamnValuableNFT _token = token; // gas savings

        if (price == 0) {
            revert InvalidPrice();
        }

        // I though that maybe overwriting the prices would be an option but I guess the owner of the IDs is checked here
        if (msg.sender != _token.ownerOf(tokenId)) {
            revert CallerNotOwner(tokenId);
        }

        if (_token.getApproved(tokenId) != address(this) && !_token.isApprovedForAll(msg.sender, address(this))) {
            revert InvalidApproval();
        }

        offers[tokenId] = price;

        // @audit I guess this should increment offersCount but it increments the offers mapping
        // -> Wrong assumption, it increments the offersCount because the first storage slot is taken by _status of ReentrancyGuard
        assembly {
            // gas savings
            sstore(0x02, add(sload(0x02), 0x01))
        }

        emit NFTOffered(msg.sender, tokenId, price);
    }

    function buyMany(uint256[] calldata tokenIds) external payable nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            unchecked {
                _buyOne(tokenIds[i]);
            }
        }
    }

    function _buyOne(uint256 tokenId) private {
        uint256 priceToPay = offers[tokenId];
        if (priceToPay == 0) {
            revert TokenNotOffered(tokenId);
        }

        if (msg.value < priceToPay) {
            revert InsufficientPayment();
        }

        // @audit Unchecked, underflow possible
        --offersCount;

        // transfer from seller to buyer
        DamnValuableNFT _token = token; // cache for gas savings
        _token.safeTransferFrom(_token.ownerOf(tokenId), msg.sender, tokenId);

        // pay seller using cached token
        payable(_token.ownerOf(tokenId)).sendValue(priceToPay);

        emit NFTBought(msg.sender, tokenId, priceToPay);
    }

    // Why needs the contract to receive ETH?
    receive() external payable {}
}
