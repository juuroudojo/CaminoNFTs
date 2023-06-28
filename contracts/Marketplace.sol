// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/ILazyMint.sol";
import "./interfaces/IRoyalty.sol";

contract Marketplace is AccessControl, IERC1155Receiver {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    Counters.Counter itemId;
    IERC20 public token;
    uint256 public serviceFee;
    uint256 public totalFee;
    uint256 public bidMultiplier;
    uint256[] public supportedStandards;

    
    // Struct containing details about each item on auction
    struct Item {
        uint256 standard; // Standard of the NFT (e.g. ERC721, ERC1155)
        uint256 tokenId;  // Token ID of the NFT
        uint256 startingPrice; // Base price of the NFT
        uint256 itemsAvailable; // Number of NFTs available for sale
        uint256 listingTime; // Time when the listing starts
        uint256 expirationTime; // Time when the listing ends
        uint256 bookPrice; // Minimum price for the auction
        address nftAddress; // Address of the NFT
        address seller; // Address of the seller
        bool lazy; // Whether the NFT is lazyMint or not (for more info refer here: https://www.alchemy.com/overviews/lazy-minting)
        Type saleType; // Type of sale (FixedPrice or Auction)
    }

    // Struct containing details about bid
    struct Bid {
        uint256 maxBid;
        address bidderAddress;
    }

    enum Type {
        FixedPrice,
        Auction
    }

    //itemId => Item
    mapping(uint256 => Item) public items;
    //itemId => Bid
    mapping(uint256 => Bid) public itemBids;

    // Royalty functionality (refer to ERC2981)
    mapping(address => uint256) private userRoyalties;
    // LazyMint part (refer to LazyMint)
    mapping(uint256 => uint256) private lazyListings;
    mapping(address => uint) timelock;
    mapping(address => uint) blacklist;

    modifier itemExists(uint256 _id) {
        require(_id <= itemId.current(), "itemExists:Item Id out of bounds");
        require(items[_id].startingPrice > 0, "itemExists: Item not listed");
        _;
    }

    // Events for listing/buying functionality
    
    event List(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed itemId,
        uint256 tokenId,
        uint256 basePrice,
        uint256 itemsAvailable,
        uint256 listingTime,
        uint256 expirationTime
    );

    event Cancel(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed itemId,
        uint256 tokenId,
        uint256 itemsAvailable
    );

    event Sold(
        uint256 indexed itemId,
        address indexed seller,
        address indexed buyer,
        address nftAddress,
        uint256 tokenId,
        uint256 totalPrice,
        uint256 itemsAmount
    );

    event BidOffered(
        uint256 indexed itemId,
        uint256 indexed tokenId,
        address indexed bidder,
        address nftAddress,
        uint256 bidAmount
    );

    event OfferRetracted(
        uint256 indexed itemId,
        uint256 indexed tokenId,
        address indexed bidder,
        address nftAddress,
        uint256 bidAmount
    );
    
    constructor(
        address _platformManager,
        uint256 _serviceFee,
        uint256 _bidMultiplier,
        address _token
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _platformManager);

        serviceFee = _serviceFee;
        bidMultiplier = _bidMultiplier;
        token = IERC20(token);
    }

    /**  @dev Allows user to list items for sale
    * @param _nftMaxCopies - Maximum number of copies of the NFT
    * @param _tokenId - Token ID of the NFT
    * @param _basePrice - Base price of the NFT
    * @param _nftAmount - Number of NFTs to be listed
    * @param _listingTime - Time when the listing starts
    * @param _expirationTime - Time when the listing ends
    * @param _bookPrice - Minimum price for the auction
    * @param _nftAddress - Address of the NFT
    * @param _lazyMint - Whether the NFT is lazyMint or not (for more info refer here: https://www.alchemy.com/overviews/lazy-minting)
    * @param _saleType - Type of sale (FixedPrice or Auction)
    */
    function listItem(
        uint256 _standard,
        uint256 _nftMaxCopies,
        uint256 _tokenId,
        uint256 _basePrice,
        uint256 _nftAmount,
        uint256 _listingTime,
        uint256 _expirationTime,
        uint256 _bookPrice,
        address _nftAddress,
        bool _lazyMint,
        Type _saleType
    ) external {
        uint256 standard;

        // Checks if the standard is supported
        for (uint256 i = 0; i < supportedStandards.length; i++) {
            if (supportedStandards[i] == _standard) {
                standard = supportedStandards[i];
            } 
        }

        require(standard != 0, "listItem: Standard not supported!");
        require(_nftAddress != address(0), "listItem: Zero address!");

        // Adjusts the relevant id
        itemId.increment();
        uint256 itemId = itemId.current();

        // Checks timings
        require(
            _expirationTime > _listingTime,
            "listItem: Too late!"
        );
        require(
            _listingTime >= block.timestamp,
            "listItem: Incorrect time input!"
        );

        // Checks the price
        require(_basePrice != 0, "listItem: Zero price!");
        require(_nftAmount != 0, "listItem: Can't be zero!");

        if (_lazyMint) {
            if (ILazyMint(_nftAddress).getMaxTokens(_tokenId) == 0) {
                require(
                    _nftMaxCopies >= _nftAmount,
                    "listItem: Max copies less than nft amount!"
                );
                lazyListings[_tokenId] = _nftAmount;
                ILazyMint(_nftAddress).setMaxTokens(_tokenId, _nftMaxCopies);
                ILazyMint(_nftAddress).setCreator(_tokenId, _msgSender());
            } else {
                require(
                    lazyListings[_tokenId] +
                        _nftAmount +
                        ILazyMint(_nftAddress).totalSupply(_tokenId) <=
                        ILazyMint(_nftAddress).getMaxTokens(_tokenId),
                    "listItem: Max copies exceeded!"
                );
                require(
                    ILazyMint(_nftAddress).getCreator(_tokenId) ==
                        _msgSender(),
                    "listItem: Access denied!"
                );
                lazyListings[_tokenId] += _nftAmount;
            }
        }

        if (_saleType == Type.Auction) {
            require(
                _bookPrice >= _basePrice,
                "listItem: Reserve price is lower than base price"
            );
            require(
                _nftAmount == 1,
                "listItem: more than one copy for auction"
            );
        }

        // Checks if the user has approved the marketplace to transfer the NFT. Not a security
        require(
            IERC1155(_nftAddress).isApprovedForAll(_msgSender(), address(this)),
            "listItem: NFT not approved for marketplace"
        );

        items[itemId] = Item(
            standard,
            _tokenId,
            _basePrice,
            _nftAmount,
            _listingTime,
            _expirationTime,
            _bookPrice,
            _nftAddress,
            _msgSender(),
            _lazyMint,
            _saleType
        );

        if (!_lazyMint) {
            IERC1155(_nftAddress).safeTransferFrom(
                _msgSender(),
                address(this),
                _tokenId,
                _nftAmount,
                ""
            );
        }

        emit List(
            _msgSender(),
            _nftAddress,
            itemId,
            _tokenId,
            _basePrice,
            _nftAmount,
            _listingTime,
            _expirationTime
        );
    }

    // @dev Allows user to cancel the listing
    // @param _itemId - ID of the item to be cancelled
    function cancelListing(uint256 _itemId) external itemExists(_itemId) {
        Item memory i = items[_itemId];
        uint256 bid = itemBids[_itemId].maxBid;
        // requires the user to be the seller
        require(
            i.seller == _msgSender(),
            "cancelListing: User not welcome!"
        );
        // checks if the auction is not finalized
        if (i.saleType == Type.Auction) {
            if (bid >= i.bookPrice) {
                require(
                    block.timestamp < i.expirationTime,
                    "cancelListing: Yaroslav Stepanyak!"
                );
                _refund(bid, itemBids[_itemId].bidderAddress);
            }
        }

        uint256 id = i.tokenId;
        uint256 amount = i.itemsAvailable;
        bool islazyMint = i.lazy;

        // updates the record
        delete (items[_itemId]);
        delete (itemBids[_itemId]);

        if (islazyMint) {
            lazyListings[i.tokenId] -= amount;
        } else {
            IERC1155(i.nftAddress).safeTransferFrom(address(this), _msgSender(), id, amount, "");
        }

        emit Cancel(_msgSender(), i.nftAddress, _itemId, id, amount);
    }

    // @dev Allows user to make bid on items active for auction
    // @param _itemId - ID of the item to be bid on
    // @param _bidAmount - Amount to be bid
    function makeBid(uint256 _itemId, uint256 _bidAmount)
        external 
        itemExists(_itemId)
    {
        Item memory i = items[_itemId];
        uint256 _oldBid = itemBids[_itemId].maxBid;

        require(
            _msgSender() != i.seller,
            "buyItem: Can't bid on your own item!"
        );

        require(
            i.saleType == Type.Auction,
            "makeBid: Not an auction!"
        );
        require(
            i.listingTime < block.timestamp,
            "makeBid: Auction not started!"
        );
        require(
            i.expirationTime > block.timestamp,
            "makeBid: Auction expired!"
        );

        if (_oldBid == 0) {
            require(
                _bidAmount >= i.startingPrice,
                "makeBid: Bid is too low!"
            );
        } else {
            require(
                _bidAmount >= _oldBid + (_oldBid * bidMultiplier) / 10000,
                "makeBid: Bid is too low!"
            );
            _refund(_oldBid, itemBids[_itemId].bidderAddress);
        }

        itemBids[_itemId].maxBid = _bidAmount;
        itemBids[_itemId].bidderAddress = _msgSender();
        token.safeTransferFrom(_msgSender(), address(this), _bidAmount);

        emit BidOffered(
            _itemId,
            i.tokenId,
            _msgSender(),
            i.nftAddress,
            _bidAmount
        );
    }

    // @dev Allows user to buy items active for fixed price sale
    // @param _itemId - ID of the item to be bought
    // @param _nftAmount - Number of NFTs to be bought
    // @param _voucher - Voucher for lazy minting (described in ILazyMint)
    // @param _signature - Signature for lazy minting (An offchain signature following EIP-712 standard, for more info refer here: https://eips.ethereum.org/EIPS/eip-712)
    function buyItem(
        uint256 _itemId,
        uint256 _nftAmount,
        ILazyMint.NFTVoucher calldata voucher,
        bytes memory signature
    ) public payable itemExists(_itemId) {
        Item memory i = items[_itemId];
        require(
            _msgSender() != i.seller,
            "buyItem: seller itself cannot buy"
        );
        require(
            i.saleType == Type.FixedPrice,
            "buyItem: Not on fixed price sale"
        );

        require(
            i.expirationTime > block.timestamp,
            "buyItem: Sale expired"
        );
        require(
            block.timestamp >= i.listingTime,
            "buyItem: Sale not started"
        );
        require(
            i.itemsAvailable >= _nftAmount,
            "buyItem: Not enough tokens on sale"
        );

        uint256 _totalPrice = i.startingPrice * _nftAmount;
        token.safeTransferFrom(_msgSender(), address(this), _totalPrice);

        if (!i.lazy) {
            _purchase(_itemId, _totalPrice, _nftAmount, _msgSender());
        } else {
            _purchaseWithLazyMinting(
                _itemId,
                _nftAmount,
                _totalPrice,
                _msgSender(),
                voucher,
                signature
            );
        }
    }

    // @dev Allows user to claim the NFT supporting lazy minting by redeeming the Voucher and verifying the signature
    // @param _itemId - ID of the item to be claimed
    // @param _voucher - Voucher for lazy minting (described in ILazyMint)
    // @param _signature - Signature for lazy minting (An offchain signature following EIP-712 standard, for more info refer here: https://eips.ethereum.org/EIPS/eip-712)
    function claimNFT(
        uint256 _itemId,
        ILazyMint.NFTVoucher calldata voucher,
        bytes memory signature
    ) external itemExists(_itemId) {
        Item memory i = items[_itemId];
        uint256 price = itemBids[_itemId].maxBid;
        uint256 _nftAmount = i.itemsAvailable;

        require(
            block.timestamp > i.expirationTime,
            "claimNFT: Auction still on!"
        );
        require(
            _msgSender() == itemBids[_itemId].bidderAddress,
            "claimNFT: Access denied!"
        );

        if (price < i.bookPrice) {
            revert("claimNFT: < book price");
        }
        if (i.lazy) {
            _purchaseWithLazyMinting(
                _itemId,
                _nftAmount,
                price,
                _msgSender(),
                voucher,
                signature
            );
        } else {
            _purchase(_itemId, price, _nftAmount, _msgSender());
        }
    }

    // @dev Allows seller to respond to the offers made on the items on auction
    // @param _itemId - ID of the item to be claimed
    // @param _voucher - Voucher for lazy minting (described in ILazyMint)
    // @param _signature - Signature for lazy minting (An offchain signature following EIP-712 standard, for more info refer here: https://eips.ethereum.org/EIPS/eip-712)
    function acceptOffer(
        uint256 _itemId,
        ILazyMint.NFTVoucher calldata voucher,
        bytes memory signature
    ) external itemExists(_itemId) {
        Item memory i = items[_itemId];
        uint256 price = itemBids[_itemId].maxBid;

        require(
            _msgSender() == i.seller,
            "acceptOffer: Access denied!"
        );
        require(price > 0, "acceptOffer: Nothing to accept!");

        uint256 _nftAmount = i.itemsAvailable;

        if (i.lazy) {
            _purchaseWithLazyMinting(
                _itemId,
                _nftAmount,
                price,
                itemBids[_itemId].bidderAddress,
                voucher,
                signature
            );
        } else {
            _purchase(
                _itemId,
                price,
                _nftAmount,
                itemBids[_itemId].bidderAddress
            );
        }
    }

    // @dev Allows seller to retract the offer made on the item, if specific requirements are met
    // @param _itemId - ID of the item to be claimed
    function retractOffer(uint256 _itemId) external itemExists(_itemId) {
        Item memory i = items[_itemId];

        require(
            _msgSender() == itemBids[_itemId].bidderAddress,
            "retractOffer: Access denied!"
        );
        require(
            block.timestamp > i.expirationTime,
            "retractOffer: Auction still on!"
        );

        uint256 amount = itemBids[_itemId].maxBid;

        delete (itemBids[_itemId]);

        token.safeTransfer(_msgSender(), amount);

        emit OfferRetracted(
            _itemId,
            i.tokenId,
            _msgSender(),
            i.nftAddress,
            amount
        );
    }

    function withdrawRoyalty() external {
        uint256 amount = userRoyalties[_msgSender()];
        require(amount != 0, "withdrawRoyalty: Nothing to withdraw!");
        userRoyalties[_msgSender()] = 0;
        token.transfer(_msgSender(), amount);
    }

    // @dev Allows to purchase the NFT using LazyMinting
    // @param _itemId - ID of the item to be claimed
    // @param _nftAmount - Number of NFTs to be bought
    // @param _totalPrice - Total price of the NFTs
    // @param _buyer - Address of the buyer
    // @param _voucher - Voucher for lazy minting (described in ILazyMint)
    // @param _signature - Signature for lazy minting (An offchain signature following EIP-712 standard, for more info refer here: https://eips.ethereum.org/EIPS/eip-712)
    function _purchaseWithLazyMinting(
        uint256 _itemId,
        uint256 _nftAmount,
        uint256 _totalPrice,
        address _buyer,
        ILazyMint.NFTVoucher calldata voucher,
        bytes memory signature
    ) internal {
        Item storage i = items[_itemId];
        (
            address[] memory _creators,
            uint256[] memory _royalties,
            uint256 _totalRoyalty
        ) = _getRoyalty(i.nftAddress, i.tokenId, _totalPrice);

        i.itemsAvailable -= _nftAmount;
        lazyListings[i.tokenId] -= _nftAmount;

        ILazyMint(i.nftAddress).redeem(
            _buyer,
            voucher,
            _nftAmount,
            signature
        );
        emit Sold(
            _itemId,
            i.seller,
            _buyer,
            i.nftAddress,
            i.tokenId,
            _totalPrice,
            _nftAmount
        );
        // distributing the royalties
        for (uint16 i = 0; i < _creators.length; i += 1) {
            userRoyalties[_creators[i]] += _royalties[i];
        }
        uint256 serviceFee_ = _getServiceFee(_totalPrice);
        totalFee += serviceFee_;
        uint256 payment = _totalPrice - _totalRoyalty - serviceFee_;
        token.safeTransfer(i.seller, payment);

        if (i.itemsAvailable == 0) {
            delete (items[_itemId]);
            delete (itemBids[_itemId]);
        }
    }

    // @dev Internal function to purchase the NFT
    // @param _standard - Address of the standard to be added
    // @param _itemId - ID of the item to be claimed
    // @param _totalPrice - Total price of the NFTs
    // @param _nftAmount - Number of NFTs to be bought
    // @param _receiver - Address of the buyer
    function _purchase(
        uint256 _itemId,
        uint256 _totalPrice,
        uint256 _nftAmount,
        address _receiver
    ) internal {
        uint256 serviceFee_ = _getServiceFee(_totalPrice);
        // Getting the info about royalties
        Item storage i = items[_itemId];
        (
            address[] memory _creators,
            uint256[] memory _royalties,
            uint256 _totalRoyalty
        ) = _getRoyalty(i.nftAddress, i.tokenId, _totalPrice);

        uint256 payment = _totalPrice - _totalRoyalty - serviceFee_;
        i.itemsAvailable -= _nftAmount;
        totalFee += serviceFee_;

        //Transferring payment to the seller
        token.safeTransfer(i.seller, payment);

        // Distributing the royalties
        for (uint16 i = 0; i < _creators.length; i += 1) {
            userRoyalties[_creators[i]] += _royalties[i];
        }

        //Transferring the NFTs
        IERC1155(i.nftAddress).safeTransferFrom(
            address(this),
            _receiver,
            i.tokenId,
            _nftAmount,
            ""
        );

        emit Sold(
            _itemId,
            i.seller,
            _receiver,
            i.nftAddress,
            i.tokenId,
            _totalPrice,
            _nftAmount
        );

        if (i.itemsAvailable == 0) {
            delete (items[_itemId]);
            delete (itemBids[_itemId]);
        }
    }

    // @dev Allows owner of the platform to withdraw the service fee
    // @param account - Address of the account to which the service fee is to be transferred
    // @param amount - Amount of service fee to be transferred
    function withdrawServiceFee(address account, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            totalFee >= amount,
            "withdrawServiceFee: Insufficient funds!"
        );
        totalFee -= amount;
        token.safeTransfer(account, amount);
    }

    // @dev Allows owner of the platform to manage the standards supported by the platform
    // @param _standard - Address of the standard to be added
    function addStandard(uint256 _standard) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for(uint256 i = 0; i < supportedStandards.length; i++) {
            require(supportedStandards[i] != _standard, "addStandard: Standard already supported!");
        }
        supportedStandards.push(_standard);
    }

    // @dev Allows owner of the platform to manage the standards supported by the platform
    // @param _standard - Address of the standard to be removed
    function removeStandard(uint256 _standard) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < supportedStandards.length; i++) {
            if (supportedStandards[i] == _standard) {
                supportedStandards[i] = supportedStandards[supportedStandards.length - 1];
                supportedStandards.pop();
                break;
            } else {
                revert("removeStandard: Standard not supported!");
            }
        }
    }

    // @dev Internal function called when a bid is outdated to refund the bidder
    function _refund(uint256 amount, address receiver) internal {
        token.safeTransfer(receiver, amount);
    }

    // @dev Internal function to get the royalty info
    function _getRoyalty(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _amount
    )
        internal
        view
        returns (
            address[] memory recipients,
            uint256[] memory values,
            uint256 total
        )
    {
        (recipients, values, total) = IRoyalty(_nftAddress).royaltyInfo(
            _tokenId,
            _amount
        );
    }

    // @dev Internal function to get the service fee
    function _getServiceFee(uint256 _amount) internal view returns (uint256) {
        return (_amount * serviceFee) / 10000;
    }

    // @dev Function serving as a leverage to act upon receiving an ERC1155 token, can manage the permissions to receive the token
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    // @dev Same as above, but for batch transfers
    function onERC1155BatchReceived(
        address,
        address,
        uint[] calldata,
        uint[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                )
            );
    }
}