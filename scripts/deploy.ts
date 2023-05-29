import { ethers } from "hardhat";

async function main() {
  const Token = await ethers.getContractFactory("TestToken")
  const token = await Token.deploy(ethers.utils.parseEther("100000"))

  const managerAddress = ethers.constants.AddressZero // to be replaced with the address maintaining the platform (preferably a multisig)
  const Marketplace = await ethers.getContractFactory("Marketplace")
  const marketplace = await Marketplace.deploy(managerAddress, 0, 0, token.address)
 
  console.log("Token deployed to ${token.address}")
  console.log("Marketplace deployed to ${marketplace.address}")

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
