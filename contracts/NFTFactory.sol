//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/INFT721.sol";

contract NFTFactory is AccessControl, VRFConsumerBaseV2 {
    IERC721 private nft721;

    VRFCoordinatorV2Interface private COORDINATOR;

    uint currentTokenId;

    /// How many confirmations the Chainlink node
    /// should wait before responding.
    uint16 requestConfirmations = 3;

    /// The limit for how much gas to use for the callback
    /// request to `fulfillRandomWords` function.
    uint32 callbackGasLimit = 200000;

    /// How many random values to request.
    uint32 numWords = 1;

    uint64 subscriptionId;

    bytes32 keyHash =
        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

    mapping(uint256 => address) public requestToSender;

    // Mapping to track if an account has already used freeMint function
    mapping(address => bool) public _freemint;

    event RequestedRandomness(uint256 requestId, address from);

    event ReceivedRandomness(uint256 requestId, uint256 randomNum, address to);

    /** @dev Contract contains a basic implementation of requesting randomness from Chainlink VRF oracle.
    **  @notice The infrastructure is an abstraction, as far as at the time of writing this contract the required Chainlink infrastructure
    **  is not yet available on Camino network.
    */
    constructor(
        address _nft721,
        uint64 _subscriptionId,
        address _vrfCoordinator
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        nft721 = IERC721(_nft721);
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
    }

    // @dev Handles the request for randomness to the Chainlink node.
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        address to = requestToSender[requestId];
        uint256 id = (randomWords[0] % 7) + 1;

        // nft721.mint(to, id);

        emit ReceivedRandomness(requestId, id, to);
    }
}