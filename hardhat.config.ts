import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";

import { config as dotenvConfig } from 'dotenv'
import { resolve } from 'path'
dotenvConfig({ path: resolve(__dirname, './.env') })

const POLYGON_MUMBAI_RPC_PROVIDER = process.env.POLYGON_MUMBAI_RPC_PROVIDER || ''
const PRIVATE_KEY = process.env.PRIVATE_KEY || ''
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || ''

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.13',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          }

        }
      },
    ],
  },
  networks: {
    hardhat: {},
    mumbai: {
      accounts: ["0x" + PRIVATE_KEY],
      url: POLYGON_MUMBAI_RPC_PROVIDER,
    },
  },
  etherscan: {
    apiKey: POLYGONSCAN_API_KEY,
  },
  mocha: {
    timeout: 100000000
  },
  abiExporter: {
    path: './data/abi',
    runOnCompile: false,
    clear: false,
    flat: false,
    only: [],
    except: [],
    spacing: 2,
    pretty: false,
    format: "json",
    filter: () => true,
    rename: undefined
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [],
  }
};

export default config;
