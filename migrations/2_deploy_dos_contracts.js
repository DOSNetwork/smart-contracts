var DOSAddressBridge = artifacts.require("./DOSAddressBridge.sol");
var DOSOnChainSDK = artifacts.require("./DOSOnChainSDK.sol");
var DOSProxy = artifacts.require("./DOSProxy.sol");

module.exports = function(deployer, network) {
  if (network === "development") {
    deployer.deploy(DOSAddressBridge);
    deployer.deploy(DOSOnChainSDK);
    deployer.deploy(DOSProxy);
  }
}
