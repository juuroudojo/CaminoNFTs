// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILazyMint {
    
    struct NFTVoucher {
        uint256 tokenId;
        uint256 nftAmount;
        uint256 price;
        uint256 startDate;
        uint256 endDate;
        address maker;
        address nftAddress;
        string tokenURI;
    }

    function redeem(
        address minter,
        NFTVoucher calldata voucher,
        uint256 nftAmount,
        bytes memory signture
    ) external;

    function setCreator(uint256 id, address _creator) external;

    function setMaxTokens(uint256 tokenId, uint256 amount) external;

    function totalSupply(uint256 tokenId) external view returns (uint256);

    function getCreator(uint256 tokenId) external view returns (address);

    function getMaxTokens(uint256 tokenId) external view returns (uint256);
}
