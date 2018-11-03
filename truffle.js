var HDWalletProvider = require("truffle-hdwallet-provider");
var infura_token = "8e609c76fce442f8a1735fbea9999747";

// Replace with valid mnemonic
var mnemonic = "aaa bbb ccc ddd eee fff ggg hhh iii jjj kkk lll";

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
  }
};
