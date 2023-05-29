// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract ERC2981Contract is ERC165 {
    struct Royalty {
        address payable recipient;
        uint256 value;
    }

    mapping(uint256 => Royalty) private _royalties;

    constructor() {
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_royalties[tokenId].recipient != address(0), "Royalty not set for token");

        Royalty memory royalty = _royalties[tokenId];
        uint256 royaltyValue = (salePrice * royalty.value) / 100;

        return (royalty.recipient, royaltyValue);
    }

    function _setRoyalty(uint256 tokenId, address payable recipient, uint256 value) internal {
        require(value <= 100, "Royalty value should be less than or equal to 100");
        _royalties[tokenId] = Royalty(recipient, value);
    }
}

interface IERC2981 is IERC165 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}
