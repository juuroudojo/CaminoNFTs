import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import '@openzeppelin/hardhat-upgrades';

dotenv.config();



const config: HardhatUserConfig = {

  
  solidity: {
		compilers: [
			{
				version: '0.8.19',
				settings: {
					optimizer: {
						enabled: true,
						runs: 200,
					},
				},
			},
			{
				version: '0.4.17',
			},
		]},
    networks: {
    columbus: {
      url: process.env.COLUMBUS_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  };

export default config;