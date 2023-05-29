// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract HierarchicalNFT is ERC721 {

    mapping(uint256 => uint256) private _parent;
    mapping(uint256 => uint256[]) private _children;

    event Minted(address indexed creator, address indexed to, uint256 parentTokenId, uint256 tokenId);

    constructor() ERC721("HierarchicalNFT", "HNFT") {}

    function parentOf(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");

        return _parent[tokenId];
    }

    function childrenOf(uint256 tokenId) external view returns (uint256[] memory) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");

        return _children[tokenId];
    }

    function isRoot(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");

        return (_parent[tokenId] == 0);
    }

    function isLeaf(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");

        return (_children[tokenId].length == 0);
    }

    function mint(address to, uint256 tokenId, uint256 parentTokenId) public {
        require(!_exists(tokenId), "ERC721: token already minted");
        require(_exists(parentTokenId), "ERC721: parent token does not exist");

        _mint(to, tokenId);
        _parent[tokenId] = parentTokenId;
        _children[parentTokenId].push(tokenId);

        emit Minted(msg.sender, to, parentTokenId, tokenId);
    }
}


