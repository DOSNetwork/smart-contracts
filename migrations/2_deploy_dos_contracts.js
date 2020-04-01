const DOSAddressBridge = artifacts.require("./DOSAddressBridge.sol");
const CommitReveal = artifacts.require("./CommitReveal.sol");
const DOSProxy = artifacts.require("./DOSProxy.sol");
const DOSPayment = artifacts.require("./DOSPayment.sol");
const Staking = artifacts.require("./Staking.sol");
const StakingGateway = artifacts.require("./StakingGateway.sol");

// Rinkeby testnet configs
const DOSTokenRinkeby = '0x214e79c85744cd2ebbc64ddc0047131496871bee';
const DBTokenRinkeby = '0x9bfe8f5749d90eb4049ad94cc4de9b6c4c31f822';
const RewardsVaultRinkeby = '0xE222f441cb42bCFE8E46Fdecad0e633C70246BD3';
const BootstrapListRinkeby = 'https://testnet.dos.network/api/bootStrap';
// Mainnet configs
const DOSTokenMainnet = '0x70861e862e1ac0c96f853c8231826e469ead37b1';
const DBTokenMainnet = '0x68423B3B0769c739D1fe4C398C3d91F0d646424f';
const RewardsVaultMainnet = '0x70861e862e1ac0c96f853c8231826e469ead37b1';
const BootstrapListMainnet = 'to-be-filled';

module.exports = function(deployer, network, accounts) {
  deployer.then(async () => {
    await deployer.deploy(DOSAddressBridge);
    let bridgeInstance = await DOSAddressBridge.deployed();

    if (network == 'rinkeby') {
      await deployer.deploy(CommitReveal, DOSAddressBridge.address);
      await bridgeInstance.setCommitRevealAddress(CommitReveal.address);

      await deployer.deploy(DOSPayment, DOSAddressBridge.address, RewardsVaultRinkeby, DOSTokenRinkeby);
      await bridgeInstance.setPaymentAddress(DOSPayment.address);

      await deployer.deploy(DOSProxy, DOSAddressBridge.address, RewardsVaultRinkeby, DOSTokenRinkeby);
      await bridgeInstance.setProxyAddress(DOSProxy.address);

      await deployer.deploy(Staking, DOSTokenRinkeby, DBTokenRinkeby, RewardsVaultRinkeby, DOSAddressBridge.address);
      await deployer.deploy(StakingGateway, Staking.address);
      await bridgeInstance.setStakingAddress(StakingGateway.address);

      await bridgeInstance.setBootStrapUrl(BootstrapListRinkeby);
    } else if (network == 'mainnet') {
      await deployer.deploy(CommitReveal, DOSAddressBridge.address);
      await bridgeInstance.setCommitRevealAddress(CommitReveal.address);

      await deployer.deploy(DOSPayment, DOSAddressBridge.address, RewardsVaultMainnet, DOSTokenMainnet);
      await bridgeInstance.setPaymentAddress(DOSPayment.address);

      await deployer.deploy(DOSProxy, DOSAddressBridge.address, RewardsVaultMainnet, DOSTokenMainnet);
      await bridgeInstance.setProxyAddress(DOSProxy.address);

      await deployer.deploy(Staking, DOSTokenMainnet, DBTokenMainnet, RewardsVaultMainnet, DOSAddressBridge.address);
      await deployer.deploy(StakingGateway, Staking.address);
      await bridgeInstance.setStakingAddress(StakingGateway.address);

      await bridgeInstance.setBootStrapUrl(BootstrapListMainnet);
    }
  });
}
