// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ComposableNFT is ERC721 {
    using Counters for Counters.Counter;
    using Address for address;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("ComposableNFT", "CNFT") {}

    function createToken() public {
        _tokenIdCounter.increment();
        uint256 newItemId = _tokenIdCounter.current();
        _mint(msg.sender, newItemId);
    }

    bytes4 constant ERC998_MAGIC_VALUE = 0xcd740db5;

    mapping(uint256 => address) internal tokenIdToTokenOwner;

    mapping(uint256 => address) internal tokenIdToApproved;

    mapping(address => uint256) internal tokenOwnerToTokenCount;

    mapping(address => mapping(address => bool)) internal tokenOwnerToOperators;

    event ReceivedChild(address indexed from, uint256 indexed tokenId, address indexed childContract, uint256 childTokenId);
    event TransferChild(uint256 indexed tokenId, address indexed to, address indexed childContract, uint256 childTokenId);

    function balanceOf(address _owner) public view override returns (uint256) {
        return tokenOwnerToTokenCount[_owner];
    }

    function ownerOf(uint256 _tokenId) public view override returns (address) {
        return tokenIdToTokenOwner[_tokenId];
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) public {
        _safeTransfer(_from, _to, _tokenId, data);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns(bytes4) {
        if (!_checkOnERC721Received(from, operator, tokenId, data)) {
            return 0;
        }
        return ERC998_MAGIC_VALUE;
    }

    function onERC20Received(address, uint256, bytes calldata) external pure returns(bytes4) {
        revert("ERC20 not supported");
    }
}
