// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract Marketplace is AccessControl, IERC1155Receiver {
    IERC20 erc20;
    IERC721 nft721;
    IERC1155 nft1155;

    // Auction variables
    uint256 public lotDuration = 3 days;
    uint256 public minimalBidsQuantity = 3;

    // Struct of an item on sale
    struct ItemOnSale {
        uint standart;
        uint id;
        uint amount;
        address seller;
        address owner;
        uint price;
        bool listed;
    }

    // Struct of an item on auction
    struct ItemOnAuction {
        uint standart;
        uint id;
        uint amount;
        address seller;
        uint startingTime;
        uint startingPrice;
        uint bidsQuantity;
        uint winningBid;
        address winningAddress;
        bool over;
    }

    ItemOnAuction[] public _itemsOnAuction;

    mapping(uint256 => ItemOnSale) _itemsOnSale;
    mapping(address => uint) timelock;
    mapping(address => uint) blacklist;

    // Events for listing/buying functionality
    event ListItem(
        uint _standart,
        uint _id,
        uint _amount,
        address _seller,
        address _owner,
        uint _price
    );

    event BuyItem(
        uint _standart,
        uint _id,
        uint _amount,
        address _seller,
        address _buyer,
        uint _price
    );

    event CancelItem(
        uint _standart,
        uint _id,
        uint _amount,
        address _seller,
        uint _price
    );

    event MakeBid(uint256 _id, uint256 _amount, address _from);

    event ListItemOnAuction(
        uint _index,
        uint _standart,
        uint _id,
        uint _amount,
        address _seller,
        uint _startingPrice
    );

    event AuctionFinished(
        uint _index,
        uint _standart,
        uint _id,
        uint _amount,
        address _seller,
        uint _startingPrice,
        address _winner,
        uint _winningPrice,
        uint _bidsQuantity
    );

    bytes32 public constant OWNER = keccak256(abi.encodePacked("OWNER"));

    constructor(
        address _erc20,
        address _erc721,
        address _erc1155
    ) {
        erc20 = IERC20(_erc20);
        nft721 = IERC721(_erc721);
        nft1155 = IERC1155(_erc1155);

        _grantRole(OWNER, msg.sender);
    }

    function listItem(
        uint _standart,
        uint _id,
        uint _amount,
        uint _price
    ) public {
        require(blacklist[msg.sender] < 2, "You are blacklisted!");
        require(_standart == 721 || _standart == 1155, "Wrong standart!");
        require(_price > 0, "Can't be zero!");

        if (_standart == 721) {
            require(_amount == 1, "721 can only be 1!");
            require(nft721.ownerOf(_id) == msg.sender, "Not an owner!");

            nft721.transferFrom(msg.sender, address(this), _id);

            _itemsOnSale[_id] = ItemOnSale(
                _standart,
                _id,
                1,
                msg.sender,
                address(this),
                _price,
                true
            );
        } else {
            require(
                nft1155.balanceOf(msg.sender, _id) >= _amount,
                "Insufficient balance!"
            );

            nft1155.safeTransferFrom(
                msg.sender,
                address(this),
                _id,
                _amount,
                ""
            );

            _itemsOnSale[_id] = ItemOnSale(
                _standart,
                _id,
                _amount,
                msg.sender,
                address(this),
                _price,
                true
            );
        }

        emit ListItem(
            _standart,
            _id,
            _amount,
            msg.sender,
            address(this),
            _price
        );
    }

    function buyItem(uint _id) public {
        require(_itemsOnSale[_id].listed == true, "Nothing to buy!");
        ItemOnSale storage nft = _itemsOnSale[_id];

        erc20.transferFrom(msg.sender, nft.seller, nft.price);

        if (nft.standart == 721) {
            nft721.safeTransferFrom(nft.owner, msg.sender, _id);
        } else {
            nft1155.safeTransferFrom(
                nft.owner,
                msg.sender,
                _id,
                nft.amount,
                ""
            );
        }

        nft.listed = false;

        emit BuyItem(
            nft.standart,
            _id,
            nft.amount,
            nft.seller,
            msg.sender,
            nft.price
        );
    }

    // In order to stimulate more traffic on auctions, supplying more engaging bidding 1 account can only use auction once a day
    function listItemOnAuction(
        uint _standart,
        uint _id,
        uint _amount,
        uint _startingPrice
    ) public {
        require(blacklist[msg.sender] < 2, "You are blacklisted!");
        require(_standart == 721 || _standart == 1155, "Wrong standart!");
        require(_startingPrice > 0, "Can't be zero!");
        require(
            block.timestamp >= timelock[msg.sender],
            "You can only use auction once a day!"
        );

        if (_standart == 721) {
            require(_amount == 1, "Not 1!");
            require(nft721.ownerOf(_id) == msg.sender, "Not an owner!");
            nft721.transferFrom(msg.sender, address(this), _id);
        } else {
            require(
                nft1155.balanceOf(msg.sender, _id) >= _amount,
                "Insufficient balance!"
            );
            nft1155.safeTransferFrom(
                msg.sender,
                address(this),
                _id,
                _amount,
                ""
            );
        }

        _itemsOnAuction.push(
            ItemOnAuction(
                _standart,
                _id,
                _amount,
                msg.sender,
                block.timestamp,
                _startingPrice,
                0,
                _startingPrice,
                address(0),
                false
            )
        );

        uint lotID = _itemsOnAuction.length - 1;
        timelock[msg.sender] = block.timestamp + 12 hours;

        emit ListItemOnAuction(
            lotID,
            _standart,
            _id,
            _amount,
            msg.sender,
            _startingPrice
        );
    }

    function makeBid(uint _id, uint _amount) public {
        require(_itemsOnAuction.length > _id, "No such lot!");

        ItemOnAuction storage lot = _itemsOnAuction[_id];

        require(
            block.timestamp - lot.startingTime < lotDuration,
            "Lot has expired!"
        );
        require(_amount > lot.winningBid, "Wrong amount!");

        erc20.transferFrom(msg.sender, address(this), _amount);

        if (lot.winningAddress != address(0)) {
            erc20.transfer(lot.winningAddress, lot.winningBid);
        }

        lot.winningBid = _amount;
        lot.winningAddress = msg.sender;
        lot.bidsQuantity += 1;

        emit MakeBid(_id, _amount, msg.sender);
    }

    function finishAuction(uint _id) public {
        require(_itemsOnAuction.length > _id, "No such lot!");
        ItemOnAuction storage item = _itemsOnAuction[_id];
        require(!item.over, "Lot has expired!");
        require(
            block.timestamp - item.startingTime >= lotDuration,
            "Wrong timestamp!"
        );

        item.over = true;

        if (item.bidsQuantity <= minimalBidsQuantity) {
            if (item.winningAddress != address(0)) {
                erc20.transfer(item.winningAddress, item.winningBid);
                item.winningAddress = address(0);
            }

            if (item.standart == 721) {
                nft721.transferFrom(address(this), item.seller, item.id);
            } else {
                nft1155.safeTransferFrom(
                    address(this),
                    item.seller,
                    item.id,
                    item.amount,
                    ""
                );
            }
        } else {
            erc20.transfer(item.seller, item.winningBid);

            if (item.standart == 721) {
                nft721.transferFrom(
                    address(this),
                    item.winningAddress,
                    item.id
                );
            } else {
                nft1155.safeTransferFrom(
                    address(this),
                    item.winningAddress,
                    item.id,
                    item.amount,
                    ""
                );
            }
        }

        emit AuctionFinished(
            _id,
            item.standart,
            item.id,
            item.amount,
            item.seller,
            item.startingPrice,
            item.winningAddress,
            item.winningBid,
            item.bidsQuantity
        );
    }

    function cancelAuction(uint _id) public {
        require(_itemsOnAuction.length > _id, "No such lot!");
        ItemOnAuction storage item = _itemsOnAuction[_id];
        require(!item.over, "Lot has expired!");

        if (item.winningAddress != address(0)) {
            erc20.transfer(item.winningAddress, item.winningBid);
            item.winningAddress = address(0);
        }

        if (item.standart == 721) {
            nft721.transferFrom(address(this), item.seller, item.id);
        } else {
            nft1155.safeTransferFrom(
                address(this),
                item.seller,
                item.id,
                item.amount,
                ""
            );
        }

        item.over = true;

        blacklist[msg.sender] += 1;

        emit AuctionFinished(
            _id,
            item.standart,
            item.id,
            item.amount,
            item.seller,
            item.startingPrice,
            address(0),
            item.winningBid,
            item.bidsQuantity
        );
    }

    function cancel(uint _id) public {
        require(_itemsOnSale[_id].listed == true, "Nothing to cancel!");

        ItemOnSale storage nft = _itemsOnSale[_id];

        require(msg.sender == nft.seller, "Not an owner!");

        if (nft.standart == 721) {
            nft721.safeTransferFrom(nft.owner, msg.sender, _id);
        } else {
            nft1155.safeTransferFrom(
                nft.owner,
                msg.sender,
                _id,
                nft.amount,
                ""
            );
        }

        nft.listed = false;

        blacklist[msg.sender] += 1;

        emit CancelItem(nft.standart, _id, nft.amount, nft.seller, nft.price);
    }

    function mint721(address _to, string memory _tokenURI)
        public
        onlyRole(OWNER)
    {
        nft721.mint(_to, _tokenURI);
    }

    function mint1155(
        address _to,
        uint _id,
        uint _amount,
        bytes memory _data
    ) public onlyRole(OWNER) {
        nft1155.mint(_to, _id, _amount, _data);
    }

    function getLotInfo(uint256 _id)
        public
        view
        returns (ItemOnAuction memory lot)
    {
        return _itemsOnAuction[_id];
    }

    function onERC1155Received(
        address,
        address,
        uint,
        uint,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

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