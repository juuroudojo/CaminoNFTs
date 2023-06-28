import { ethers } from 'ethers';
import { privateToAddress, toBuffer } from 'ethereumjs-util';
import sigUtil from 'eth-sig-util';

const SIGNING_DOMAIN_NAME = 'CAMINO';
const SIGNING_DOMAIN_VERSION = '1';

interface NFTVoucher {
  tokenId: number;
  nftAmount: number;
  price: number;
  startDate: number;
  endDate: number;
  maker: string;
  nftAddress: string;
  tokenURI: string;
}

class SignWallet {
  private contractAddress: string;
  private signer: ethers.Signer;
  private types: any;

  constructor(contractAddress: string, signer: ethers.Signer) {
    this.contractAddress = contractAddress;
    this.signer = signer;

    this.types = {
      EIP712Domain: [
        { name: 'name', type: 'string' },
        { name: 'version', type: 'string' },
        { name: 'chainId', type: 'uint256' },
        { name: 'verifyingContract', type: 'address' },
      ],
      NFTVoucher: [
        { name: 'tokenId', type: 'uint256' },
        { name: 'nftAmount', type: 'uint256' },
        { name: 'price', type: 'uint256' },
        { name: 'startDate', type: 'uint256' },
        { name: 'endDate', type: 'uint256' },
        { name: 'maker', type: 'address' },
        { name: 'nftAddress', type: 'address' },
        { name: 'tokenURI', type: 'string' },
      ],
    };
  }

  async getDomain(): Promise<any> {
    const chainId = await this.signer.getChainId();
    const domain = {
      name: SIGNING_DOMAIN_NAME,
      version: SIGNING_DOMAIN_VERSION,
      chainId: chainId,
      verifyingContract: this.contractAddress,
    };

    return domain;
  }

  async getSignature(nftVoucher: NFTVoucher): Promise<string> {
    const domain = await this.getDomain();

    // Create the EIP712 typed data
    const typedData = {
        types: this.types,
        domain: domain,
        primaryType: 'NFTVoucher',
        message: nftVoucher,
    };

    // Sign the typed data
    const signature = await (this.signer as any)._signTypedData(domain, typedData.types, typedData.message);

    return signature;
}

}

export default SignWallet;
