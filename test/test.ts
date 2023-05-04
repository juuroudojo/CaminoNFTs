import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import * as dotenv from "dotenv";
dotenv.config();

describe("Marketplace.sol", function () {
  let ERC20Factory: ContractFactory;
  let erc20: Contract;
  let NFT721Factory: ContractFactory;
  let nft721: Contract;
  let NFT1155Factory: ContractFactory;
  let nft1155: Contract;
  let MarketplaceFactory: ContractFactory;
  let marketplace: Contract;
  let Ichigo: SignerWithAddress;
  let Rukiya: SignerWithAddress;
  let Kenpachi: SignerWithAddress;
  const days = 86400;
  const hours = 3600;

  beforeEach(async function () {
    [Ichigo, Rukiya, Kenpachi] = await ethers.getSigners();

    ERC20Factory = await ethers.getContractFactory("ERC20");
    erc20 = await ERC20Factory.deploy("BOBER", "BBR", 18);
    await erc20.deployed();

    NFT721Factory = await ethers.getContractFactory("NFT721");
    nft721 = await NFT721Factory.deploy();
    await nft721.deployed();

    NFT1155Factory = await ethers.getContractFactory("NFT1155");
    nft1155 = await NFT1155Factory.deploy();
    await nft1155.deployed();

    MarketplaceFactory = await ethers.getContractFactory("Marketplace");
    marketplace = await MarketplaceFactory.deploy(erc20.address, nft721.address, nft1155.address);
    await marketplace.deployed();

    await nft721.grantRole(nft721.OWNER(), marketplace.address);
    await nft1155.grantRole(nft1155.OWNER(), marketplace.address);

    await erc20.mint(Rukiya.address, 200000);
    await erc20.mint(Kenpachi.address, 200000);
    await erc20.connect(Rukiya).approve(marketplace.address, 200000);
    await erc20.connect(Kenpachi).approve(marketplace.address, 200000);

    await marketplace.connect(Ichigo).mint721(Ichigo.address, "/id_1");
    await marketplace.connect(Ichigo).mint721(Ichigo.address, "/id_2");
    await nft721.connect(Ichigo).approve(marketplace.address, 1);
    await nft721.connect(Ichigo).approve(marketplace.address, 2);

    await marketplace.connect(Ichigo).mint1155(Ichigo.address, 3, 1000, "0x");
    await marketplace.connect(Ichigo).mint1155(Ichigo.address, 4, 1000, "0x");
    await nft1155.connect(Ichigo).setApprovalForAll(marketplace.address, true);
  });

  describe("Selling functionality", function () {
    it("listItem: Should list a 721 item for sale", async function () {
      await marketplace.connect(Ichigo).listItem(721, 1, 1, 100);
    });

    it("listItem: Should list 1155 items for sale", async function () {
      await marketplace.connect(Ichigo).listItem(1155, 3, 1, 100);
    });

    it("listItem: Should fail to list 1155 items for sale (Insufficient balance)", async function () {
      await expect(marketplace.connect(Ichigo).listItem(1155, 3, 1337, 100)).to.be.revertedWith("Insufficient balance!");
    });

    it("listItem: Should fail to list an item for sale (Not 1)", async function () {
      await expect(marketplace.connect(Ichigo).listItem(721, 1, 5, 100)).to.be.revertedWith("721 can only be 1!");
    });

    it("listItem: Should fail to list an item for sale (Wrong standart)", async function () {
      await expect(marketplace.connect(Ichigo).listItem(420, 1, 1, 100)).to.be.revertedWith("Wrong standart!");
    });

    it("listItem: Should fail to list an item for sale (Must be at least 1 Wei)", async function () {
      await expect(marketplace.connect(Ichigo).listItem(721, 1, 1, 0)).to.be.revertedWith("Can't be zero!");
    });

    it("listItem: Should fail to list an item for sale (Not an owner)", async function () {
      await expect(marketplace.connect(Rukiya).listItem(721, 1, 1, 100)).to.be.revertedWith("Not an owner!");
    });

    it("listItem: Should fail to list an item for sale (Blacklisted)", async function () {
      await marketplace.connect(Ichigo).listItem(721, 1, 1, 100);
      await marketplace.connect(Ichigo).cancel(1);
      await nft721.connect(Ichigo).approve(marketplace.address, 1);
      await marketplace.connect(Ichigo).listItem(721, 1, 1, 100);
      await marketplace.connect(Ichigo).cancel(1);
      await nft721.connect(Ichigo).approve(marketplace.address, 1);
      expect(marketplace.connect(Ichigo).listItem(721, 1, 1, 100)).to.be.revertedWith("You are blacklisted!");
    })

    it("buyItem: Should buy the 721 listed item", async function () {
      await marketplace.connect(Ichigo).listItem(721, 1, 1, 100);
      await marketplace.connect(Rukiya).buyItem(1);
    });

    it("buyItem: Should buy the 1155 listed item", async function () {
      await marketplace.connect(Ichigo).listItem(1155, 3, 10, 100);
      await marketplace.connect(Rukiya).buyItem(3);
    });

    it("buyItem: Should fail to buy the listed item (Nothing to buy)", async function () {
      await marketplace.connect(Ichigo).listItem(721, 1, 1, 100);
      await marketplace.connect(Rukiya).buyItem(1);
      await expect(marketplace.connect(Rukiya).buyItem(1)).to.be.revertedWith("Nothing to buy!");
    });

    it("cancel: Should cancel the selling of a 721 listed item", async function () {
      await marketplace.connect(Ichigo).listItem(721, 1, 1, 100);
      await marketplace.connect(Ichigo).cancel(1);
    });

    it("cancel: Should cancel the selling of an 1155 listed item", async function () {
      await marketplace.connect(Ichigo).listItem(1155, 3, 10, 100);
      await marketplace.connect(Ichigo).cancel(3);
    });

    it("cancel: Should fail to cancel the selling of a listed item (Nothing to cancel)", async function () {
      await marketplace.connect(Ichigo).listItem(721, 1, 1, 100);
      await marketplace.connect(Ichigo).cancel(1);
      await expect(marketplace.connect(Ichigo).cancel(1)).to.be.revertedWith("Nothing to cancel!");
    });

    it("cancel: Should fail to cancel the selling of a listed item (Not an owner)", async function () {
      await marketplace.connect(Ichigo).listItem(721, 1, 1, 100);
      await expect(marketplace.connect(Rukiya).cancel(1)).to.be.revertedWith("Not an owner!");
    });
  });

  describe("Auction functionality", function () {
    it("listAuction: Should list a 721 item", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(721, 1, 1, 100);
    });

    it("listAuction: Should list an 1155 item", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 1000);
    });

    it("listAuction: Should fail to list an item (Blacklisted)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(721, 1, 1, 100);
      await marketplace.connect(Ichigo).cancelAuction(0);

      await ethers.provider.send('evm_increaseTime', [12 * hours]);
      await ethers.provider.send('evm_mine', []);

      await nft721.connect(Ichigo).approve(marketplace.address, 2);
      await marketplace.connect(Ichigo).listItemOnAuction(721, 2, 1, 100);
      await marketplace.connect(Ichigo).cancelAuction(1);

      await ethers.provider.send('evm_increaseTime', [12 * hours]);
      await ethers.provider.send('evm_mine', []);

      await nft721.connect(Ichigo).approve(marketplace.address, 2);

      expect(marketplace.connect(Ichigo).listItemOnAuction(721, 2, 1, 100)).to.be.revertedWith("You are blacklisted!");
    })

    it("listAuction: Should fail to list an item (Wrong standart)", async function () {
      await expect(marketplace.connect(Ichigo).listItemOnAuction(7215, 3, 10, 1000)).to.be.revertedWith("Wrong standart!");
    });

    it("listAuction: Should fail to list an item (Must be at least 1 Wei)", async function () {
      await expect(marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 0)).to.be.revertedWith("Can't be zero!");
    });

    it("listAuction: Should fail to list a 721 item (Not 1)", async function () {
      await expect(marketplace.connect(Ichigo).listItemOnAuction(721, 1, 10, 10)).to.be.revertedWith("Not 1!");
    });

    it("listAuction: Should fail to list a 721 item (Not an owner)", async function () {
      await expect(marketplace.connect(Rukiya).listItemOnAuction(721, 1, 1, 10)).to.be.revertedWith("Not an owner!");
    });

    it("listAuction: Should fail to list an 1155 item (Insufficient balance)", async function () {
      await expect(marketplace.connect(Rukiya).listItemOnAuction(1155, 3, 99, 10)).to.be.revertedWith("Insufficient balance!");
    });

    it("listAuction: Should fail to list an item(Can't list twice a day)", async function () {
      await marketplace.listItemOnAuction(721, 1, 1, 10);
      expect(marketplace.listItemOnAuction(721, 1, 1, 10)).to.be.revertedWith("You can only list item once a day!");
    })

    it("makeBid: Should make a bid", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(721, 1, 1, 100);
      await marketplace.connect(Rukiya).makeBid(0, 200);
    });

    it("makeBid: Should fail to make a bid (No such lot)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(721, 1, 1, 100);
      await expect(marketplace.connect(Rukiya).makeBid(1, 200)).to.be.revertedWith("No such lot!");
    });

    it("makeBid: Should fail to make a bid (Wrong amount)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(721, 1, 1, 100);
      await expect(marketplace.connect(Rukiya).makeBid(0, 100)).to.be.revertedWith("Wrong amount!");
    });

    it("makeBid: Should fail to make a bid (Lot is outdated)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(721, 1, 1, 100);
      await ethers.provider.send('evm_increaseTime', [4 * days]);
      await ethers.provider.send('evm_mine', []);
      await expect(marketplace.connect(Rukiya).makeBid(0, 200)).to.be.revertedWith("Lot has expired!");
    });

    it("makeBid: Should transfer back previous highest bid", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(721, 1, 1, 100);
      await marketplace.connect(Rukiya).makeBid(0, 200);
      await marketplace.connect(Kenpachi).makeBid(0, 300);
    });

    it("finishAuction: Should finish (4 bids, 4 days)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(721, 1, 1, 100);
      await marketplace.connect(Rukiya).makeBid(0, 200);
      await marketplace.connect(Kenpachi).makeBid(0, 300);
      await marketplace.connect(Rukiya).makeBid(0, 400);
      await marketplace.connect(Kenpachi).makeBid(0, 500);

      await ethers.provider.send('evm_increaseTime', [4 * days]);
      await ethers.provider.send('evm_mine', []);

      await marketplace.connect(Ichigo).finishAuction(0);
    });

    it("finishAuction: Should finish (0 bids, 4 days)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(721, 1, 1, 100);

      await ethers.provider.send('evm_increaseTime', [4 * days]);
      await ethers.provider.send('evm_mine', []);

      await marketplace.connect(Ichigo).finishAuction(0);
    });

    it("finishAuction: Should finish (2 bids, 4 days)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(721, 1, 1, 100);
      await marketplace.connect(Rukiya).makeBid(0, 200);
      await marketplace.connect(Kenpachi).makeBid(0, 300);

      await ethers.provider.send('evm_increaseTime', [4 * days]);
      await ethers.provider.send('evm_mine', []);

      await marketplace.connect(Ichigo).finishAuction(0);
    });

    it("finishAuction: Should finish (2 bids, 4 days, 1155)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 100);
      await marketplace.connect(Rukiya).makeBid(0, 200);
      await marketplace.connect(Kenpachi).makeBid(0, 300);

      await ethers.provider.send('evm_increaseTime', [4 * days]);
      await ethers.provider.send('evm_mine', []);

      await marketplace.connect(Ichigo).finishAuction(0);
    });

    it("finishAuction: Should finish (4 bids, 10 days, 1155)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 100);
      await marketplace.connect(Rukiya).makeBid(0, 200);
      await marketplace.connect(Kenpachi).makeBid(0, 300);
      await marketplace.connect(Rukiya).makeBid(0, 400);
      await marketplace.connect(Kenpachi).makeBid(0, 500);

      await ethers.provider.send('evm_increaseTime', [10 * days]);
      await ethers.provider.send('evm_mine', []);

      await marketplace.connect(Ichigo).finishAuction(0);
    });

    it("finishAuction: Should fail to finish (No such lot)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 100);

      await ethers.provider.send('evm_increaseTime', [4 * days]);
      await ethers.provider.send('evm_mine', []);

      await expect(marketplace.connect(Ichigo).finishAuction(1)).to.be.revertedWith("No such lot!");
    });

    it("finishAuction: Should fail to finish (Lot is outdated)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 100);

      await ethers.provider.send('evm_increaseTime', [4 * days]);
      await ethers.provider.send('evm_mine', []);

      await marketplace.connect(Ichigo).finishAuction(0);
      await expect(marketplace.connect(Ichigo).finishAuction(0)).to.be.revertedWith("Lot has expired!");
    });

    it("finishAuction: Should fail to finish (Wrong timestamp)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 100);

      await ethers.provider.send('evm_increaseTime', [2 * days]);
      await ethers.provider.send('evm_mine', []);

      await expect(marketplace.connect(Ichigo).finishAuction(0)).to.be.revertedWith("Wrong timestamp!");
    });

    it("cancelAuction: Should cancel an auction with an active bid", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 100);
      await marketplace.connect(Rukiya).makeBid(0, 110);
      await marketplace.connect(Ichigo).cancelAuction(0);
    });

    it("cancelAuction: Should fail to cancel (No, such lot)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 100);
      expect(marketplace.connect(Ichigo).cancelAuction(1)).to.be.revertedWith("No such lot!");
    });

    it("cancelAuction: Should fail to cancel (Lot has expired)", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 100);
      await marketplace.connect(Ichigo).cancelAuction(0);

      expect(marketplace.connect(Ichigo).cancelAuction(0)).to.be.revertedWith("Lot has expired!");
    });

    it("getLotInfo: Should get lot info", async function () {
      await marketplace.connect(Ichigo).listItemOnAuction(1155, 3, 10, 100);
      await marketplace.connect(Rukiya).makeBid(0, 200);
      await marketplace.connect(Kenpachi).makeBid(0, 300);
      await marketplace.connect(Rukiya).makeBid(0, 400);
      await marketplace.connect(Kenpachi).makeBid(0, 500);

      await ethers.provider.send('evm_increaseTime', [5 * days]);
      await ethers.provider.send('evm_mine', []);

      await marketplace.connect(Ichigo).getLotInfo(0);
    });

    it("mint721: Should fail to mint(Access control)", async function () {
      expect(marketplace.connect(Rukiya).mint721(Rukiya.address, "URI")).to.be.revertedWith('revertMessage');
    });

    it("mint1155: Should fail to mint(Access control)", async function () {
      expect(marketplace.connect(Rukiya).mint1155(Rukiya.address, 1, 2, "0x")).to.be.revertedWith('revertMessage');
    });
  });

  describe("NFT721.sol", function () {
    it("mint: Should fail to mint (AccessControl)", async function () {
      expect(nft721.connect(Kenpachi).mint(Kenpachi.address, "/id_1")).to.be.revertedWith('revertMessage');
    })

    it("tokenURI: Should return URI of a token", async function () {
      await nft721.connect(Ichigo).tokenURI(1);
    });

    it("Should return a bool indicating whether the interface is supported", async function () {
      expect(await nft721.supportsInterface("0x70a08231"))
        .to.be.a('boolean');
    });
  });

  describe("NFT1155.sol", function () {
    it("mint: Should fail to mint (AccessControl)", async function () {
      expect(nft1155.connect(Kenpachi).mint(Kenpachi.address, 1, 1000, "0x")).to.be.revertedWith('revertMessage');
    })

    it("mint: Should fail to mintBatch (AccessControl)", async function () {
      expect(nft1155.connect(Kenpachi).mintBatch(Kenpachi.address, [1, 2], [1000,], "0x")).to.be.revertedWith('revertMessage');
    })

    it("uri: Should return URI of a token", async function () {
      await nft1155.connect(Ichigo).uri(3);
    });

    it("Should return a bool indicating whether the interface is supported", async function () {
      expect(await nft1155.supportsInterface("0x70a08231"))
        .to.be.a('boolean');
    });

    it("onERC1155BatchReceived: Should return data", async function () {
      await nft1155.grantRole(nft1155.OWNER(), Ichigo.address);
      await nft1155.connect(Ichigo).mintBatch(Ichigo.address, [3, 4], [2000, 2000], "0x");
      await nft1155.connect(Ichigo).setApprovalForAll(marketplace.address, true);
      await nft1155.connect(Ichigo).safeBatchTransferFrom(Ichigo.address, marketplace.address, [3, 4], [2000, 2000], "0x");
    });
  });

  describe("ERC20.sol", function () {
    it("name: Should return the name of a token", async function () {
      expect(await erc20.connect(Ichigo).name()).to.equal("BOBER");
    });

    it("symbol: Should return the symbol of a token", async function () {
      expect(await erc20.connect(Ichigo).symbol()).to.equal("BBR");
    });

    it("decimals: Should return the decimals of a token", async function () {
      expect(await erc20.connect(Ichigo).decimals()).to.equal(18);
    });

    it("totalSupply: Should return the totalSupply of a token", async function () {
      await erc20.connect(Ichigo).totalSupply();
    });

    it("balanceOf: Should return token balance for a given address", async function () {
      expect(await erc20.connect(Ichigo).balanceOf(Ichigo.address)).to.equal(0);
    });

    it("mint: Should fail to mint(Not an owner)", async function () {
      expect(erc20.connect(Kenpachi).mint(Kenpachi.address, 1337)).to.be.revertedWith("Not an owner");
    });

    it("burn: Should burn tokens", async function () {
      await erc20.connect(Ichigo).mint(Ichigo.address, 100);
      await erc20.connect(Ichigo).burn(Ichigo.address, 100);
    });

    it("burn: Should fail to burn tokens (Insufficient balance)", async function () {
      await expect(erc20.connect(Ichigo).burn(Ichigo.address, 100000000000)).to.be.revertedWith("Insufficient balance");
    });

    it("burn: Should fail to burn tokens (You are not an owner)", async function () {
      await expect(erc20.connect(Rukiya).burn(Ichigo.address, 100000000000)).to.be.revertedWith("You are not an owner");
    });

    it("transfer: Should fail to transfer tokens (Insufficient balance)", async function () {
      await expect(erc20.connect(Ichigo).transfer(Rukiya.address, 1000000000000000)).to.be.revertedWith("Insufficient balance");
    });

    it("transferFrom: Should fail to transferFrom tokens (Insufficient balance)", async function () {
      await expect(erc20.connect(Ichigo).transferFrom(Ichigo.address, Rukiya.address, 1000000000000000)).to.be.revertedWith("Insufficient balance");
    });

    it("transferFrom: Should fail to transferFrom tokens (Insufficient balance)", async function () {
      await erc20.connect(Ichigo).approve(Rukiya.address, 1000000000000000);
      await expect(erc20.connect(Ichigo).transferFrom(Ichigo.address, Rukiya.address, 1000000000000000)).to.be.revertedWith("Insufficient balance");
    });

    it("transferFrom: Should fail to transferFrom tokens (Insufficient allowance)", async function () {
      await erc20.connect(Ichigo).mint(Ichigo.address, 1000000000000000);
      await expect(erc20.connect(Ichigo).transferFrom(Ichigo.address, Rukiya.address, 1000000000000000)).to.be.revertedWith("Insufficient allowance");
    });
  });
});