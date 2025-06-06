import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ethers";
import "@typechain/hardhat";
import dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          evmVersion: "cancun",
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    testnet: {
      //url: "https://rpc-hyperliquid-testnet.imperator.co/evm",
      url: "https://rpc.hyperliquid-testnet.xyz/evm",
      chainId: 998,
      accounts: {
        mnemonic: process.env.TESTNET_MNEMONIC ?? "",
      },
    },
  },
  typechain: {
    //outDir: "scripts/typechain-types",
    target: "ethers-v6",
  },
};

export default config;
