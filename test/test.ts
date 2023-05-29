import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { parseEther, parseUnits } from "ethers/lib/utils";
import { ethers, network, upgrades } from "hardhat";
import { BigNumber, BigNumberish} from "ethers";
import { SignWallet } from '../scripts/signature'
import hre from 'hardhat'
import { Marketplace, LazyMintNFT, TestToken } from "../typechain";

async function getImpersonatedSigner(address: string): Promise<SignerWithAddress> {
  await ethers.provider.send(
    'hardhat_impersonateAccount',
    [address]
  );

  return await ethers.getSigner(address);
}

async function skipDays(days: number) {
  ethers.provider.send("evm_increaseTime", [days * 86400]);
  ethers.provider.send("evm_mine", []);
}

let count = 0
function counter() {
	count = count + 1
	return count
}

async function sendEth(users: SignerWithAddress[]) {
  let signers = await ethers.getSigners();

  for (let i = 0; i < users.length; i++) {
    await signers[0].sendTransaction({
      to: users[i].address,
      value: parseEther("1.0")

    });
  }
}

const now = async () => (await ethers.provider.getBlock('latest')).timestamp

describe("Marketplace", function () {
  let Ichigo: SignerWithAddress;
  let Rukiya: SignerWithAddress;
  let Kenpachi: SignerWithAddress;

  let marketplace: Marketplace;
  let nft: LazyMintNFT;
  let token: TestToken;

  beforeEach(async function () {
    [Ichigo, Rukiya, Kenpachi] = await ethers.getSigners();

    let Token = await ethers.getContractFactory("TestToken");
    token = await Token.deploy(ethers.utils.parseEther("10000"));

    let Marketplace = await ethers.getContractFactory("Marketplace");
    marketplace = await Marketplace.deploy(Ichigo.address, 500, 500, token.address);
    

    let NFT = await ethers.getContractFactory("LazyMintNFT");
    nft = await NFT.deploy(marketplace.address);
  });

  describe("Main functionality", function () {
    it('should resolve signature to signer address', async () => {
			const NFTVoucher = {
				tokenId: counter(),
				nftAmount: 1,
				price: ethers.utils.parseEther('5'),
				startDate: (await now()) + 43200,
				endDate: (await now()) + 172800, 
				maker: Ichigo.address,
				nftAddress: nft.address,
				tokenURI: '42',
			}
			const signWallet = new SignWallet(nft.address, signer)
			const signature = await signWallet.getSignature(NFTVoucher)

			expect(await nft.check(NFTVoucher, signature)).to.equal(
				signer.address
			)
		})
		it('should list nft', async () => {
			const NFTVoucher = {
				tokenId: counter(),
				nftAmount: 10,
				price: ethers.utils.parseEther('4'),
				startDate: (await now()) + 43200,
				endDate: (await now()) + 172800,
				maker: signer.address,
				nftAddress: nft.address,
				tokenURI: 'asapferg',
			}

			try {
				const txn = await nft.setApprovalForAll(
					marketplace.address,
					true
				)
				await txn.wait()
			} catch (e) {
				console.log(e)
			}

			const signWallet = new SignWallet(nft.address, signer)
			const signature = await signWallet.getSignature(NFTVoucher)

			await marketplace.listItem(
        '1155',
				'20',
				NFTVoucher.tokenId,
				NFTVoucher.price,
				NFTVoucher.nftAmount,
				NFTVoucher.startDate,
				NFTVoucher.endDate,
				'0',
				NFTVoucher.nftAddress,
				true,
				'0'
			)

			const itemDetails = await marketplace.marketItems('1')

			expect(itemDetails.tokenId).to.equal(NFTVoucher.tokenId) // NFTVoucher.tokenId
			expect(itemDetails.basePrice).to.equal(ethers.utils.parseEther('1'))
			expect(itemDetails.itemsAvailable).to.equal(10) // NFTVoucher.nftAmount
			expect(itemDetails.listingTime).to.equal(NFTVoucher.startDate)
			expect(itemDetails.expirationTime).to.equal(NFTVoucher.endDate)
			expect(itemDetails.reservePrice).to.equal(0)
			expect(itemDetails.seller).to.equal(signer.address)
			expect(itemDetails.lazyMint).to.equal(true)
			expect(itemDetails.saleKind).to.equal(0)
		})
  });
});