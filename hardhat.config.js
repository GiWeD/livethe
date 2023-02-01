require("@nomiclabs/hardhat-waffle");

require('@openzeppelin/hardhat-upgrades');

require("@nomiclabs/hardhat-etherscan");

require("@nomiclabs/hardhat-web3");

//require("hardhat-gas-reporter");

const { PRIVATEKEY, APIKEY } = require("./pvkey.js") 

module.exports = {
  // latest Solidity version
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ]
  },

  networks: {
    
    optimism: {
      url: "https://mainnet.optimism.io",
      chainId: 10,
      accounts: PRIVATEKEY
    },

    bsc: {
      url: "https://bsc-dataseed1.binance.org",
      chainId: 56,
      accounts: PRIVATEKEY
    },

    bscTestnet: {
      url: "https://bsc-testnet.public.blastapi.io",
      chainId: 97,
      accounts: PRIVATEKEY
    },


    hardhat: {
      forking: {
          url: "https://bsc-dataseed1.binance.org",
          chainId: 56
      },
      //accounts: []
    }
  
  },

  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: APIKEY
  }

}