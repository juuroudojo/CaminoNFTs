// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFT721 is ERC721, AccessControl {
    uint256 tokenCounter;
    bytes32 public constant OWNER = keccak256(abi.encodePacked("OWNER"));

    constructor() ERC721("BBRS", "BOBERS") {
        tokenCounter = 1;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    mapping(uint256 => string) private _URIs;

    function mint(address _to, string memory _tokenURI)
        public
        onlyRole(OWNER)
        returns (uint256)
    {
        uint256 newItemId = tokenCounter;
        _safeMint(_to, newItemId);
        _setTokenURI(newItemId, _tokenURI);
        tokenCounter = tokenCounter + 1;

        return newItemId;
    }

    function _setTokenURI(uint256 id, string memory _tokenURI) internal {
        _URIs[id] = _tokenURI;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return _URIs[id];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC721)
        returns (bool)
    {
        return
            interfaceId == type(IAccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}