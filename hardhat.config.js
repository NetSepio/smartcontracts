require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-etherscan");

const fs = require('fs');
require('dotenv').config()

/**
 * 
 * @param {string} key 
 * //Function to get value from env
 */
function getEnv(key) {
  return [key];
}

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// API_KEY & PRIVATE_KEY
const RINKEBY_RPC_URL = process.env.RINKEBY_RPC_URL || "https://eth-rinkeby.alchemyapi.io/v2/your-api-key"
const MATICMUM_RPC_URL = process.env.MATICMUM_RPC_URL || "https://rpc-mumbai.maticvigil.com"
const MNEMONIC = process.env.MNEMONIC || "mnemonic"
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || process.env.POLYGONSCAN_API_KEY || "Etherscan API key"
// optional
const PRIVATE_KEY = process.env.PRIVATE_KEY || "wallet private key"

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
    },
    rinkeby: {
      url: RINKEBY_RPC_URL,
      accounts: {
        mnemonic: MNEMONIC,
      },
    },
    maticmum: {
      url: MATICMUM_RPC_URL,
      //accounts: [`0x${ETH_PRIVATE_KEY}`],
      accounts: {
        mnemonic: MNEMONIC,
      },
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 20000
  }
};
