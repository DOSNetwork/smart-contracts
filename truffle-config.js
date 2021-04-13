const HDWalletProvider = require("@truffle/hdwallet-provider");
const assert = require('assert');
const infura_token = "8e609c76fce442f8a1735fbea9999747";
const mainnetInfura = `https://mainnet.infura.io/v3/${infura_token}`;
const rinkebyInfura = `https://rinkeby.infura.io/v3/${infura_token}`;
const okchainTest = 'https://exchaintest.okexcn.com';
const hecoTestnet = 'https://http-testnet.hecochain.com';
const heco = 'https://http-mainnet.hecochain.com';
const bscTestnet = 'https://data-seed-prebsc-1-s2.binance.org:8545/';
const bsc = 'https://bsc-dataseed.binance.org';
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
    okchainTest: {
      provider: () => new HDWalletProvider(pk, okchainTest),
      network_id: 65,
      gas: 8000000,
      gasPrice: 1e9  // 1 Gwei
    },
    hecoTestnet: {
      provider: () => new HDWalletProvider(pk, hecoTestnet),
      network_id: 256,
      gas: 8000000,
      gasPrice: 1e9  // 1 Gwei
    },
    heco: {
      provider: () => new HDWalletProvider(pk, heco),
      network_id: 128,
      gas: 8000000,
      gasPrice: 2e9  // 2 Gwei
    },
    bscTestnet: {
      provider: () => new HDWalletProvider(pk, bscTestnet),
      networkCheckTimeout: 100000,
      timeoutBlocks: 2000,
      network_id: 97,
      gas: 8000000,
      gasPrice: 10e9  // 10 Gwei
    },
    bsc: {
      provider: () => new HDWalletProvider(pk, bsc),
      networkCheckTimeout: 100000,
      timeoutBlocks: 200,
      network_id: 56,
      gas: 8000000,
      gasPrice: 5e9  // 5 Gwei
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
