<p align="center">
  <img src="https://github.com/juuroudojo/images/blob/main/camino-logo.png" height="150" />
</p>

<br/>

# Camino NFTs 

## [DEPLOYMENT GUIDE](https://github.com/juuroudojo/CaminoNFTs/blob/master/DEPLOYMENT.md)

This repository showcases a sample set of NFT projects and an ecosystem employing it exploring different ERC standards and ways of working with them. Below you'll find a comprehensive description of what you can do with it, how each of the standard is different, as well as a guide walking you through the whole process of deploying the project and trying it out yourself.

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Installation and Setup](#installation-and-setup)
5. [User Guide](#user-guide)
   - [ERC721](#erc721)
   - [ERC1155](#erc1155)
   - [ERC988](#erc988)
   - [Marketplace](#marketplace)
6. [Contributing](#contributing)
7. [License and Contact Information](#license-and-contact-information)

## Description

Repo contains implementations of the following projects:

### [ERC721](https://eips.ethereum.org/EIPS/eip-721)
A standard for non-fungible tokens (NFTs), allowing for unique, indivisible tokens. The first widely-used ERC standard, which introduced a set of rules for NFT interactions. It is a better fit for scenarios where individual ownership and unique token metadata are critical, and are prioritised over scalability and optimisation

### [ERC1155](https://eips.ethereum.org/EIPS/eip-1155)
A standard that combines the benefits of ERC20 and ERC721, allowing for both fungible and non-fungible tokens within a single contract. Besides creating the common base for fungible and nonfungible tokens interactions the standard also introduces solutions tackling gas/storage optimisation.
The approach in general is a much more flexible one, and is a common choice for both: simple implementations, that are not dependant on strict approach to managing/tracking assets, which 721 enforces, and a more complicated infrastructure requiring additional interoperability and scalability features.

### [ERC988](https://eips.ethereum.org/EIPS/eip-998)
A standard for composable tokens, enabling tokens to own other tokens and create complex hierarchies. It takes chooses a different approach and takes a step forward tackling the coexistence of fungible and nonfungible.
The core of its structure is a family-tree. Assets can record info about each other, be set to be transferred together automatically. This standard is more advanced compared to the previous ones and is highly scalable. The combinations allow for a creation of a really versatile infrastructure. 

There are two ways of creating a composable NFT:

1. Top-Down composable tokens record information about their child tokens. Any ERC-721 token can be transferred into a top-down composable token. Similar to that of a folder, you can store and transfer tokens in and out of it. You can place as many individual tokens within it as you like, then transfer the composable as a whole.
- ERC998/ERC721 Top-Down composables are ERC-721 tokens that can receive, hold and transfer ERC721 tokens.
- ERC998/ERC20 Top-Down composables are ERC-721 tokens that can receive, hold and transfer ERC20 tokens.


2. Bottom-Up composable tokens record information about the parent tokens. Bottom-up composables can attach themselves as child tokens to other ERC-721 tokens. For instance, you can attach a whole bunch of bottom-up composables to an ERC-721 token and transfer the entire composition to someone else. By design, the recipient will now own all of the individual composables that are attached to the ERC-721 token.
- ERC998/ERC721 Bottom-Up composables are ERC-721 tokens that can attach themselves to other ERC721 tokens.
- ERC998/ERC20 Bottom-Up composables are ERC-20 tokens that can attach themselves to ERC721 tokens.

| Composable Type               | Description                                                                                                                                                                                                                                                                                      |
|-------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Top-Down Composable**       |                                                                                                                                                                                                                                                                                                  |
| ERC998/ERC721 Top-Down        | ERC-721 tokens that can receive, hold, and transfer ERC721 tokens. Top-Down composable tokens record information about their child tokens. Any ERC-721 token can be transferred into a top-down composable token, similar to a folder.                                                           |
| ERC998/ERC20 Top-Down         | ERC-721 tokens that can receive, hold, and transfer ERC20 tokens. Top-Down composable tokens record information about their child tokens. Any ERC-721 token can be transferred into a top-down composable token, similar to a folder.                                                           |
| **Bottom-Up Composable**      |                                                                                                                                                                                                                                                                                                  |
| ERC998/ERC721 Bottom-Up       | ERC-721 tokens that can attach themselves to other ERC721 tokens. Bottom-Up composable tokens record information about the parent tokens. They can be attached as child tokens to other ERC-721 tokens, allowing you to transfer the entire composition to someone else.                          |
| ERC998/ERC20 Bottom-Up        | ERC-20 tokens that can attach themselves to ERC721 tokens. Bottom-Up composable tokens record information about the parent tokens. They can be attached as child tokens to other ERC-721 tokens, allowing you to transfer the entire composition to someone else.                              |

### Marketplace
An implementation that allows users to buy, sell, list and take part in the auction, trade tokens based on these standards. It also serves as a substrate displaying how you can interact with different ERC standards, as well as underlies the differences in how they are treated on the contract level.

### NFTFactory + VRF Coordinator
This contract allows for randomised minting of NFTs. It is a part of the marketplace, but can be used as a standalone contract. It might seem weird to an outsider, but random is a tricky part in smart contract development, as far as the structure of blockchain is deterministic. Thus, the contract uses a special oracle to generate random numbers, which are then used to mint NFTs. Note, at the time of writing this, Camino network doesn't yet have the prerequired Chainlink infrastructure, which means that as of now the VRFCoordinator tool is an abstraction and not actually functioning as suggested.

## Prerequisites

To run and interact with these projects, you will need:

- [Node.js](https://nodejs.org/en/download/) (version 14.x or higher)
- [npm](https://www.npmjs.com/get-npm) (usually bundled with Node.js)
- [Hardhat](https://hardhat.org/getting-started/#overview) development environment
- [Camino Wallet](https://wallet.camino.foundation/) (Must be KYC verified)

## Project Structure

The repository is organized as follows:

- `contracts/` - Contains the Solidity smart contracts implementing the token standards and marketplace:
  - `ERC721/` - Contains the ERC721 implementation.
  - `ERC1155/` - Contains the ERC1155 implementation, including the `NFT1155` contract.
  - `ERC988/` - Contains the ERC988 implementation.
  - `Marketplace.sol` - The marketplace smart contract for buying, selling, and trading tokens.
  - `NFTFactory.sol` - A factory contract for creating new token instances.
  - `VRFCoordinator.sol` - A contract for handling randomness in the token minting process.
- `test/` - Contains the test scripts for the smart contracts. Also a good place to look for examples of how to interact with the contracts.
- `scripts/` - Contains the Hardhat deployment scripts.

## Installation and Setup

1. Clone the repository:

```bash
git clone https://github.com/juuroudojo/CaminoTokenGating.git
```

2. Install the required dependencies:

```bash
cd CaminoTokenGating
npm install
```

3. Create a `.env` file in the root directory and configure it with your MetaMask wallet's private key and a [Columbus testnet]() API key for deploying to testnets:

```dotenv
PRIVATE_KEY="your_private_key"
COLUMBUS_API_KEY="your_columbus_api_key"
```

4. Compile the smart contracts:

```bash
npx hardhat compile
```

5. Deploy the contracts to a local test network or a public testnet using Hardhat:

```bash
npx hardhat run scripts/deploy.ts --network localhost
```

## User Guide

Let's walk through some examples of how to interact with the contracts. We'll start by minting each type of token, then we'll buy and sell tokens on the marketplace.


1. **Minting tokens:** 
- - To mint ERC721 tokens, call the `mint` function with the recipient's address, token ID. Only the contract owner can mint tokens.

```typescript
// Example: Mint a token with ID 1 for the recipient
await nft721.mint(recipient, 1);
```

- To mint ERC1155 tokens, call the `mint` function with the recipient's address, token ID, amount, and any additional data. Only the contract owner can mint tokens.

```typescript
// Example: Mint 10 tokens with ID 1 for the recipient
await nft1155.mint(recipient, 1, 10, "0x");
```
- ERC1155 introduces batching, which allows calling the `mintBatch` function with the recipient's address, an array of token IDs, an array of amounts, and any additional data.

```typescript
// Example: Mint 10 tokens with ID 1 and 5 tokens with ID 2 for the recipient
await nft1155.mintBatch(recipient, [1, 2], [10, 5], "0x");
```

- To mint ERC998 tokens, call the `mint` function with the recipient's address, token ID, and any additional data. Only the contract owner can mint tokens.

```typescript



2. **Minting multiple tokens:** 

3. **Token URI:** To get the URI of a token, call the `uri` function with the token ID.

```typescript
// Example: Get the URI for token ID 1
const tokenURI = await nft1155.uri(1);
```


## Contributing

If you'd like to contribute to the project, please submit an issue or create a pull request with your proposed changes.

## License and Contact Information

This project is licensed under the [MIT License](LICENSE). For any questions or suggestions, please contact the repository owner.


