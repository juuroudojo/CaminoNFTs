// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface INFT721 {
    function mint(address to, uint256 tokenId) external;

    function burn(uint256 tokenId) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function setApprovalForAll(address operator, bool approved) external;

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);
}