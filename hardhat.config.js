require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.g.alchemy.com/v2/I_SA2ZTeK5Vc0F4fdCHfyDvuK6RJEJJK",
        blockNumber: 16213847
      }
    }
  }
};
