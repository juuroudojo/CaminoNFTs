# Camino NFTs Deployment Guide <img src=https://github.com/juuroudojo/juuroudojo/blob/main/images/image01.gif height = "90" />

## Table of Contents

- [Introduction](#introduction)
- [Deployment Structure](#deployment-structure)
- [Mainnet Deployment](#mainnet-deployment)
- [Smart Contracts](#smart-contracts)
- [Columbus Deployment](#columbus-deployment)
- [Additional Info](#additional-info)
- [Contributions](#contributions)

## Introduction

- The repo consists of many templates each one exploring different topics and created with the purpose of walking the user through a particular branch of the blockchain ecosystem. As a result, the repo is quite big and can be overwhelming to navigate. Thus, the approach to deployment is chosen to balance out the coverage of all the aspects and creating a friendly user experience.

## Deployment Structure

- For NFT & Token-gates access repo a tailored deployment format is chosen. We deploy 3 instances on NFT's: of 721, 1155, LazyMint, and a Marketplace providing the environment for interactions with these NFTs, supporting the functionalities underlining the specifics of each standard. Each NFT is permissionless for the sake of testing and can't be minted by anyone, although it is recommended to limit such interactions to maintain a realistic network state. (For the testing purposes). 

- The rest of the repo is to be deployed on testnet, but the approach there is more heavily focused on permission management. The interacgions there require some roles. (You can contact us to obtain roles for additional testing opportunies). You can also learn a lot by simply going through the tests & rest of the repo.

## Mainnet deployment

- [Marketplace.sol](r) - deployed on Columbus
- [NFT721.sol](d) - deployed on Columbus
- [NFT1155.sol](d) - deployed on Columbus
- [LazyMintNFT.sol](pu) - deployed on Columbus

## Smart Contracts

<img src=https://github.com/juuroudojo/images/blob/main/Untitled%20Diagram.drawio.png/>

- **`Marketplace.sol`** - Basic implementation of a Liquidity Pool solution omitting complex mathematical algorithms providing AMM mechanisms. User is introduced to the concept of a liquidity pool, liquidity pool tokens, exchange mechanisms, tokenomics basics, etc.

- **`NFT721.sol`** - Basic implementation of a Staking platform. Allows anyone to participate in a staking 

- **`NFT1155.sol`** - Simple ERC20 token which is used in both LiquidityPool.sol and Staking.sol. Permissionless, meaning anyone can mint tokens and use them to play around with staking. This approach also creates a realistic environment where the user can see how the platform works in dynamic conditions.

- **`LazyMintNFT.sol`** - Liquidity Pool token, which is a part of a Liquidity Pool.

- **`TestToken.sol`** - Mock ERC20 token used for testing purposes.


## Columbus Deployment

- **`NFTFactory.sol`** - Factory contract for NFT721.sol, NFT1155.sol, LazyMintNFT.sol. Orchestrates minting and burning of the NFTs.

- **`NFT721.sol`** - Basic implementation of a ERC721.

- **`NFT1155.sol`** - Basic implementation of a ERC1155.

- **`NFT988.sol`** - Basic implementation of a ERC988.

- **`LazyMintNFT.sol`** - A contract describing and providing support for LazyMint functionality.

## Other Educational Materials

Contracts in this repo are built as blocks, so that one can explore and play around by combining and/or adapting existing contracts to ones vision. The repo is also accompanied by a set of tests, which can be used as a reference for the expected behaviour of the contracts.


## Additional Info

The system is maintained by our team. If you face any issues, want some additional info/explanation or additional opportuinities to interact with the infrastructure feel free to reach out to us on [Discord](https://discord.gg/).

## Contributions

Difficulties and questions you face interacting with the templates is a valuable feedback for us. Reach out to us on [Discord](https://discord.gg/) or create an issue on GitHub. We will be happy to help you out.
