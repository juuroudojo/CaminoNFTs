//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

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

    ///  _GLSAddress ERC-1155 token contract address.
    ///  _subscriptionId Chainlink subscription ID.
    /// _vrfCoordinator VRF Coordinator contract address.
    constructor(
        address _GLSAddress,
        uint64 _subscriptionId,
        address _vrfCoordinator
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        gls = IGLS(_GLSAddress);

        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);

        subscriptionId = _subscriptionId;
    }

    /// @notice Mints a random Character.
    function getRandomCharacter() public returns (uint256 requestId) {
        // require(currentTokenId < 100, "Collection sold out!");

        require(
            _freemint[msg.sender] == false,
            "You can only mint 1 character for free!"
        );
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        requestToSender[requestId] = msg.sender;
        _freemint[msg.sender] = true;
        currentTokenId++;

        emit RequestedRandomness(requestId, msg.sender);
    }

    function buyRandomCharacter() public returns (uint256 requestId) {
        require(gls.balanceOf(msg.sender, 8) >= 100, "Not enough berries!");
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        requestToSender[requestId] = msg.sender;
        _freemint[msg.sender] = true;
        currentTokenId++;

        emit RequestedRandomness(requestId, msg.sender);
    }

    function getBerries() public payable {
        require(msg.value > 0, "Can't be zero!");
        uint amount = msg.value / 100000000;
        gls.mintBerries(msg.sender, 8, amount, "");

        currentTokenId++;
    }

    /// The actual mint of the character.
    /// Invoked by the Coordinator.
    /// Receives the requestId and randomWords array.
    /// @param requestId The same request ID obtained from `getRandomCharacter` function.
    /// @param randomWords The requested random number.
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        address to = requestToSender[requestId];
        uint256 id = (randomWords[0] % 7) + 1;

        gls.mintCharacter(to, id);

        emit ReceivedRandomness(requestId, id, to);
    }
}