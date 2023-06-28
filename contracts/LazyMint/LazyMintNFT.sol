// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/ILazyMint.sol";
import "../interfaces/IRoyalty.sol";

contract LazyMintNFT is ILazyMint, IRoyalty, ERC1155Supply, EIP712 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 private maxRoyaltyCap = 1000;
    string private constant SIGNING_DOMAIN = "Camino";
    string private constant SIGNATURE_VERSION = "1";
    address private immutable marketplace;

    using ECDSA for bytes32;

    address private signer;

    mapping(uint256 => RoyaltyInfo) private royalties;
    mapping(uint256 => address) public creator;
    mapping(uint256 => string) public _tokenURIs;
    mapping(uint256 => uint256) public maxTokens;

    struct RoyaltyInfo {
        address[] recipient;
        uint256[] amount;
    }

    event RoyaltyUpdated(
        uint256 indexed tokenId,
        uint256[] value,
        address[] recipient
    );

    event Mint(address indexed creator, uint256 tokenId, uint256 amount);

    // NFT containing Lazy Mint and Royalty logic combined.
    constructor(address _marketplace)
        ERC1155("Camino")
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        marketplace = _marketplace;
    }

    /**
    * @dev Redeems a voucher for a given tokenId and mints an NFT to the minter address
    * @param minter address to which NFT should be minted
    * @param voucher NFTVoucher struct containing the voucher information
    * @param amountToMint amount of NFTs to mint
    * @param signature correctly formatted signature
    */
    function redeem(
        address minter,
        NFTVoucher memory voucher,
        uint256 amountToMint,
        bytes memory signature
    ) external override {
        require(msg.sender == marketplace, "redeem: Unauthorized access");

        signer = _verify(voucher, signature);

        require(signer == voucher.maker, "redeem: unauthorized signer");
        require(signer != minter, "redeem: minter == buyer");

        mint(voucher.tokenId, amountToMint, voucher.maker, voucher.tokenURI);

        safeTransferFrom(signer, minter, voucher.tokenId, amountToMint, "");
    }


    /**
    * @dev View function checking the validity of the voucher
    * @param voucher NFTVoucher struct containing the voucher information
    * @param signature correctly formatted signature
    */
    function check(NFTVoucher memory voucher, bytes memory signature)
        public
        view
        returns (address)
    {
        return _verify(voucher, signature);
    }

    /**
    * @dev Returns the chainID of the network the contract is deployed on.
    * Is used in process of signature verification, one of the EIP-712 standard requirements.
    */
    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
    * @dev Mints an NFT to the minter address, called internally by redeem function
    * @param _id tokenId of the NFT to mint
    * @param _amount amount of NFTs to mint
    * @param _to address to which NFT should be minted
    * @param _tokenURI URI of the token
    */
    function mint(
        uint256 _id,
        uint256 _amount,
        address _to,
        string memory _tokenURI
    ) internal {
        _beforeTokenMint(_id, _amount, _to);
        // creator[id_] = to_;
        _setURI(_id, _tokenURI);
        _mint(_to, _id, _amount, "");

        emit Mint(_to, _id, _amount);
    }

    /** 
    * @dev verifies the signature of the voucher, follows EIP-712 standard. Takes the hash,
    * which is typed according to ILazyMint interface, and recovers the signer from the signature.
    * Verifies the validity of the request. 
    */
    function _verify(NFTVoucher memory voucher, bytes memory _signature)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);

        address _signer = digest.toEthSignedMessageHash().recover(_signature);
        return _signer;
    }

    /**  
    * @dev part of the signature verification process, follows EIP-712 standard.
    * depending on the use case, additional fields can be added increasing the security threshold.
    */
    function _hash(NFTVoucher memory voucher) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "NFTVoucher(uint256 tokenId,uint256 nftAmount,uint256 price,uint256 startDate,uint256 endDate,address maker,address nftAddress,string tokenURI)"
                        ),
                        voucher.tokenId,
                        voucher.nftAmount,
                        voucher.price,
                        voucher.startDate,
                        voucher.endDate,
                        voucher.maker,
                        voucher.nftAddress,
                        keccak256(bytes(voucher.tokenURI))
                    )
                )
            );
    }

    function getMaxTokens(uint256 id) external view override returns (uint256) {
        return maxTokens[id];
    }

    function getCreator(uint256 id) external view override returns (address) {
        return creator[id];
    }

    function setCreator(uint256 id, address _creator) external override {
        require(_msgSender() == marketplace, "setCreator: unauthorised access");
        creator[id] = _creator;
    }

    function setMaxTokens(uint256 tokenId, uint256 amount) external override {
        require(_msgSender() == marketplace, "setCreator: unauthorised access");
        maxTokens[tokenId] = amount;
    }

    function setTokenRoyalty(
        uint256 id,
        uint256[] memory value,
        address[] memory recipient
    ) external {
        uint256 _len = recipient.length;
        uint256 totalRoyalty;
        require(
            creator[id] == msg.sender,
            "setTokenRoyalty: unauthorized access"
        );
        require(value.length == _len, "setTokenRoyalty: array length mismatch");
        require(_len <= 5, "setTokenRoyalty: more than 5 recipients");
        for (uint8 i = 0; i < _len; i += 1) {
            totalRoyalty += value[i];
        }
        require(
            totalRoyalty <= maxRoyaltyCap,
            "setTokenRoyalty: royalty more than 10 percent"
        );
        royalties[id] = RoyaltyInfo(recipient, value);
        emit RoyaltyUpdated(id, value, recipient);
    }

    function totalSupply(uint256 id)
        public
        view
        override(ERC1155Supply, ILazyMint)
        returns (uint256)
    {
        return super.totalSupply(id);
    }

    function getRoyaltyInfo(uint256 id)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        RoyaltyInfo memory royalties_ = royalties[id];
        if (royalties_.amount.length == 0) {
            address[] memory recipient = new address[](1);
            uint256[] memory amount = new uint256[](1);
            recipient[0] = creator[id];
            amount[0] = 250;
            return (recipient, amount);
        }
        return (royalties_.recipient, royalties_.amount);
    }

    function getlatestTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    function royaltyInfo(uint256 id, uint256 value)
        external
        view
        override
        returns (
            address[] memory receiver,
            uint256[] memory royaltyAmounts,
            uint256 totalAmount
        )
    {
        RoyaltyInfo memory royalties_ = royalties[id];
        uint256 len = (royalties_.recipient).length;

        if (len == 0) {
            totalAmount = (value * 250) / 10000;
            receiver = new address[](1);
            royaltyAmounts = new uint256[](1);
            receiver[0] = creator[id];
            royaltyAmounts[0] = totalAmount;
        } else {
            receiver = new address[](len);
            receiver = royalties_.recipient;
            royaltyAmounts = new uint256[](len);

            uint256[] memory royalty = new uint256[](len);
            royalty = royalties_.amount;
            uint256 _royaltyAmount;
            for (uint256 i = 0; i < len; i++) {
                _royaltyAmount = (value * royalty[i]) / 10000;
                royaltyAmounts[i] = _royaltyAmount;
                totalAmount += _royaltyAmount;
            }
        }
    }

    function _setURI(uint256 id, string memory _uri) internal {
        if (bytes(_tokenURIs[id]).length == bytes("").length) {
            require(bytes(_uri).length != 0, "_setURI: tokenURI should be set");
            _tokenURIs[id] = _uri;
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155)
        returns (bool)
    {
        return ERC1155.supportsInterface(interfaceId);
    }

    function _beforeTokenMint(
        uint256 id,
        uint256 amount,
        address to_
    ) internal view {
        require(
            amount + totalSupply(id) <= maxTokens[id],
            "_beforeTokenMint: exceeding max limit of tokens set to mint"
        );
        require(
            creator[id] == to_,
            "_beforeTokenMint: unauthorized attempt to mint"
        );
        require(amount != 0, "_beforeTokenMint: amount should be positive");
    }

}
