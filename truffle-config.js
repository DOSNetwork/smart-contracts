const HDWalletProvider = require("@truffle/hdwallet-provider");
const assert = require('assert');
const infura_token = "8e609c76fce442f8a1735fbea9999747";
const mainnetInfura = `https://mainnet.infura.io/v3/${infura_token}`;
const rinkebyInfura = `https://rinkeby.infura.io/v3/${infura_token}`;
const pk = process.env.PK;

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      provider: () => new HDWalletProvider(pk, rinkebyInfura),
      network_id: 4,
      gas: 8000000
    },
    live: {
      provider: () => new HDWalletProvider(pk, mainetInfura),
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
