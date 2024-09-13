require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

const { PRIVATE_KEY, BSC_TESTNET_URL } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    bscTestnet: {
      url: BSC_TESTNET_URL,
      accounts: [`${PRIVATE_KEY}`],
      chainId: 97,
      gasPrice: 20000000000,
    },
    hardhat: {
      chainId: 31337,
      mining: {
        auto: true,
        interval: 0
      }
    }
  }
};