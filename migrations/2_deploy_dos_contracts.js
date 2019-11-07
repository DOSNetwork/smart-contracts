const DOSAddressBridge = artifacts.require("./DOSAddressBridge.sol");
const DOSOnChainSDK = artifacts.require("./DOSOnChainSDK.sol");
const CommitReveal = artifacts.require("./CommitReveal.sol");
const DOSProxy = artifacts.require("./DOSProxy.sol");
const DOSPayment = artifacts.require("./DOSPayment.sol");
const TestToken = artifacts.require("./TestToken.sol");
const Staking = artifacts.require("./Staking.sol");

module.exports = function(deployer, network) {
    deployer.deploy(DOSAddressBridge).then(function() {
        deployer.deploy(TestToken).then(function() {
            return deployer.deploy(Staking, TestToken.address,TestToken.address,TestToken.address,DOSAddressBridge.address);
        });
    });
}
