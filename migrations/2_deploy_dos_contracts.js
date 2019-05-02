var DOSAddressBridge = artifacts.require("./DOSAddressBridge.sol");
var DOSOnChainSDK = artifacts.require("./DOSOnChainSDK.sol");
var CommitReveal = artifacts.require("./CommitReveal.sol");
var DOSProxy = artifacts.require("./DOSProxy.sol");
var DOSPayment = artifacts.require("./DOSPayment.sol");


module.exports = function(deployer, network) {
  if (network === "development") {
    deployer.deploy(DOSAddressBridge);
    deployer.deploy(CommitReveal);
    deployer.deploy(DOSPayment);
    deployer.deploy(DOSProxy);
  }
}
