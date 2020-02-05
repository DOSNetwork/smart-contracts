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
    ropsten: {
      provider: new HDWalletProvider(mnemonic, "https://ropsten.infura.io/v3/" + infura_token),
      network_id: 3,
      gas: 8000000
    },
    rinkeby: {
      provider: new HDWalletProvider(mnemonic, "https://rinkeby.infura.io/v3/" + infura_token),
      network_id: 4,
      gas: 8000000  // Gas limit used for deploys, choose block gas limit
    },
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};
