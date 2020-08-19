var HDWalletProvider = require("@truffle/hdwallet-provider");
var infura_token = "8e609c76fce442f8a1735fbea9999747";

// Test mnemonic with no real value, replace with valid mnemonic
var mnemonic = "metal maple virus during involve heavy find type hour thrive maximum radar";

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      provider: () => new HDWalletProvider(mnemonic, "https://rinkeby.infura.io/v3/" + infura_token, 14, 1),
      network_id: 4,
      gas: 8000000
    },
    live: {
      provider: () => new HDWalletProvider(mnemonic, "https://mainnet.infura.io/v3/" + infura_token),
      network_id: 1,
      gas: 8000000
    },
  },
  compilers: {
    solc: {
      version: "0.5.17",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    }
  }
};
