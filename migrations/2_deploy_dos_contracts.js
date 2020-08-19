const DOSAddressBridge = artifacts.require("./DOSAddressBridge.sol");
const CommitReveal = artifacts.require("./CommitReveal.sol");
const DOSProxy = artifacts.require("./DOSProxy.sol");
const DOSPayment = artifacts.require("./DOSPayment.sol");
const Staking = artifacts.require("./Staking.sol");
const ContractGateway = artifacts.require("./ContractGateway.sol");

// Rinkeby testnet configs
const DOSTokenRinkeby = '0x214e79c85744cd2ebbc64ddc0047131496871bee';
const DBTokenRinkeby = '0x9bfe8f5749d90eb4049ad94cc4de9b6c4c31f822';
const RewardsVaultRinkeby = '0xE222f441cb42bCFE8E46Fdecad0e633C70246BD3';
const GatewayAdminRinkeby = '0xebef930796883E0A1D2f8964AEd7a59FE64e68E6';
const BootstrapListRinkeby = 'https://dashboard.dos.network/api/bootStrapRinkeby';
// Mainnet configs
const DOSTokenMainnet = '0x0A913beaD80F321E7Ac35285Ee10d9d922659cB7';
const DBTokenMainnet = '0x9456d6a22c8bdFF613366d51e3d60402cB8cFd8F';
const RewardsVaultMainnet = '0x76cEc0b88FD0F109C04F0475EBdF1648DF1c60B4';
const GatewayAdminMainnet = '0x250f871e3ccafde7b5053f321241fd8bb67a54f8';
const BootstrapListMainnet = 'https://dashboard.dos.network/api/bootStrap';


module.exports = function(deployer, network, accounts) {
  deployer.then(async () => {
    await deployer.deploy(DOSAddressBridge);
    let bridgeInstance = await DOSAddressBridge.deployed();

    if (network == 'rinkeby') {
      await bridgeInstance.setBootStrapUrl(BootstrapListRinkeby);
      // Deploying CommitReveal contracts.
      await deployer.deploy(CommitReveal, DOSAddressBridge.address);
      await bridgeInstance.setCommitRevealAddress(CommitReveal.address);


      // Deploying DOSPayment implementation & proxy contracts.
      await deployer.deploy(DOSPayment, DOSAddressBridge.address, RewardsVaultRinkeby, DOSTokenRinkeby);
      await deployer.deploy(ContractGateway, DOSPayment.address);
      await bridgeInstance.setPaymentAddress(ContractGateway.address);
      let PaymentGateway = await ContractGateway.deployed();
      await PaymentGateway.changeAdmin(GatewayAdminRinkeby);
      // Pretend the proxy address is a Payment impl. This is ok as proxy will forward
      // all the calls to the Payment impl.
      PaymentGateway = await DOSPayment.at(ContractGateway.address);
      await PaymentGateway.initialize(DOSAddressBridge.address, RewardsVaultRinkeby, DOSTokenRinkeby);


      // Note: guardianFundsAddr to call approve(PaymentGateway.address) as part of initialization.

      // Deploying DOSProxy contract.
      await deployer.deploy(DOSProxy, DOSAddressBridge.address, RewardsVaultRinkeby, DOSTokenRinkeby);
      await bridgeInstance.setProxyAddress(DOSProxy.address);


      // Deploying Staking implementation & proxy contracts.
      await deployer.deploy(Staking, DOSTokenRinkeby, DBTokenRinkeby, RewardsVaultRinkeby, DOSAddressBridge.address);
      await deployer.deploy(ContractGateway, Staking.address);
      await bridgeInstance.setStakingAddress(ContractGateway.address);
      let StakingGateway = await ContractGateway.deployed();
      await StakingGateway.changeAdmin(GatewayAdminRinkeby);
      // Pretend the proxy address is a Staking impl. This is ok as proxy will forward
      // all the calls to the Staking impl.
      StakingGateway = await Staking.at(ContractGateway.address);
      await StakingGateway.initialize(DOSTokenRinkeby, DBTokenRinkeby, RewardsVaultRinkeby, DOSAddressBridge.address);


      // Note: stakingRewardsValut to call approve(StakingGateway.address) as part of initialization.
    } else if (network == 'live') {
      await bridgeInstance.setBootStrapUrl(BootstrapListMainnet);
      // Deploying CommitReveal contracts.
      await deployer.deploy(CommitReveal, DOSAddressBridge.address);
      await bridgeInstance.setCommitRevealAddress(CommitReveal.address);


      // Deploying DOSPayment implementation & proxy contracts.
      await deployer.deploy(DOSPayment, DOSAddressBridge.address, RewardsVaultMainnet, DOSTokenMainnet);
      await deployer.deploy(ContractGateway, DOSPayment.address);
      await bridgeInstance.setPaymentAddress(ContractGateway.address);
      let PaymentGateway = await ContractGateway.deployed();
      await PaymentGateway.changeAdmin(GatewayAdminMainnet);
      // Pretend the proxy address is a Payment impl. This is ok as proxy will forward
      // all the calls to the Payment impl.
      PaymentGateway = await DOSPayment.at(ContractGateway.address);
      await PaymentGateway.initialize(DOSAddressBridge.address, RewardsVaultMainnet, DOSTokenMainnet);


      // Note: guardianFundsAddr to call approve(PaymentGateway.address) as part of initialization.


      // Deploying DOSProxy contract.
      await deployer.deploy(DOSProxy, DOSAddressBridge.address, RewardsVaultMainnet, DOSTokenMainnet);
      await bridgeInstance.setProxyAddress(DOSProxy.address);


      // Deploying Staking implementation & proxy contracts.
      await deployer.deploy(Staking, DOSTokenMainnet, DBTokenMainnet, RewardsVaultMainnet, DOSAddressBridge.address);
      await deployer.deploy(ContractGateway, Staking.address);
      await bridgeInstance.setStakingAddress(ContractGateway.address);
      let StakingGateway = await ContractGateway.deployed();
      await StakingGateway.changeAdmin(GatewayAdminMainnet);
      // Pretend the proxy address is a Staking impl. This is ok as proxy will forward
      // all the calls to the Staking impl.
      StakingGateway = await Staking.at(ContractGateway.address);
      await StakingGateway.initialize(DOSTokenMainnet, DBTokenMainnet, RewardsVaultMainnet, DOSAddressBridge.address);


      // Note: stakingRewardsValut to call approve(StakingGateway.address) as part of initialization.
    }
  });
}
