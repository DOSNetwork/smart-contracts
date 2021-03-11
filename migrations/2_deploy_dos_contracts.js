const DOSAddressBridge = artifacts.require("./DOSAddressBridge.sol");
const CommitReveal = artifacts.require("./CommitReveal.sol");
const DOSProxy = artifacts.require("./DOSProxy.sol");
const DOSPayment = artifacts.require("./DOSPayment.sol");
const Staking = artifacts.require("./Staking.sol");
const ContractGateway = artifacts.require("./ContractGateway.sol");

const configs = {
  rinkeby: {
    DOSToken: '0x214e79c85744cd2ebbc64ddc0047131496871bee',
    DBToken: '0x9bfe8f5749d90eb4049ad94cc4de9b6c4c31f822',
    RewardsVault: '0xE222f441cb42bCFE8E46Fdecad0e633C70246BD3',
    GatewayAdmin: '0xebef930796883E0A1D2f8964AEd7a59FE64e68E6',
    BootstrapList: 'https://dashboard.dos.network/api/bootStrapRinkeby',
  },
  mainnet: {
    DOSToken: '0x0A913beaD80F321E7Ac35285Ee10d9d922659cB7',
    DBToken: '0x9456d6a22c8bdFF613366d51e3d60402cB8cFd8F',
    RewardsVault: '0x76cEc0b88FD0F109C04F0475EBdF1648DF1c60B4',
    GatewayAdmin: '0x250f871e3ccafde7b5053f321241fd8bb67a54f8',
    BootstrapList: 'https://dashboard.dos.network/api/bootStrap',
  },
  hecoTestnet: {
    DOSToken: '0x3bca354b33e0a0ca6487fb51d1150f6e9c0e0e5e',
    DBToken: '0x84c6be700f2db040ed1455ac980538003cda90dd',
    RewardsVault: '0xE222f441cb42bCFE8E46Fdecad0e633C70246BD3',
    GatewayAdmin: '0xebef930796883E0A1D2f8964AEd7a59FE64e68E6',
    BootstrapList: 'https://dashboard.dos.network/api/bootStrapHeco',
  },
  heco: {
    DOSToken: '0xF50821F0A136A4514D476dC4Cc2a731e7728aFaF',
    DBToken: '0x1B7BEaa5107Ac5Fb2E8ADCAE2B64B0Ba1997EFd9',
    RewardsVault: '0xC25079a8A14FCA9a588616ebACD7b68745a3f709',
    GatewayAdmin: '0x78DBae2489CD0E961893788272AF2C85Fc03d418',
    BootstrapList: 'https://dashboard.dos.network/api/bootStrapHeco',
  },
  okchainTest: {
    DOSToken: '0x51147d0bc5be0a9d487a412e59ece23bb699461a',
    DBToken: '0x7c013b34d07ab263233372a2f385460fdedd902a',
    RewardsVault: '0xE222f441cb42bCFE8E46Fdecad0e633C70246BD3',
    GatewayAdmin: '0xebef930796883E0A1D2f8964AEd7a59FE64e68E6',
    BootstrapList: 'https://dashboard.dos.network/api/bootStrapOkchain',
  },
}

module.exports = function(deployer, network, accounts) {
  deployer.then(async () => {
    await deployer.deploy(DOSAddressBridge);
    let bridgeInstance = await DOSAddressBridge.deployed();

    if (network === 'rinkeby' || network === 'live' || network === 'hecoTestnet' || network === 'heco' || network === 'okchainTest') {
      await bridgeInstance.setBootStrapUrl(configs[network].BootstrapList);
      // Deploying CommitReveal contracts.
      await deployer.deploy(CommitReveal, DOSAddressBridge.address);
      await bridgeInstance.setCommitRevealAddress(CommitReveal.address);


      // Deploying DOSPayment implementation & proxy contracts.
      await deployer.deploy(DOSPayment, DOSAddressBridge.address, configs[network].RewardsVault, configs[network].DOSToken);
      await deployer.deploy(ContractGateway, DOSPayment.address);
      await bridgeInstance.setPaymentAddress(ContractGateway.address);
      let PaymentGateway = await ContractGateway.deployed();
      await PaymentGateway.changeAdmin(configs[network].GatewayAdmin);
      // Pretend the proxy address is a Payment impl. This is ok as proxy will forward
      // all the calls to the Payment impl.
      PaymentGateway = await DOSPayment.at(ContractGateway.address);
      await PaymentGateway.initialize(DOSAddressBridge.address, configs[network].RewardsVault, configs[network].DOSToken);


      // Note: guardianFundsAddr to call approve(PaymentGateway.address) as part of initialization.

      // Deploying DOSProxy contract.
      await deployer.deploy(DOSProxy, DOSAddressBridge.address, configs[network].RewardsVault, configs[network].DOSToken);
      await bridgeInstance.setProxyAddress(DOSProxy.address);


      // Deploying Staking implementation & proxy contracts.
      await deployer.deploy(Staking, configs[network].DOSToken, configs[network].DBToken, configs[network].RewardsVault, DOSAddressBridge.address);
      await deployer.deploy(ContractGateway, Staking.address);
      await bridgeInstance.setStakingAddress(ContractGateway.address);
      let StakingGateway = await ContractGateway.deployed();
      await StakingGateway.changeAdmin(configs[network].GatewayAdmin);
      // Pretend the proxy address is a Staking impl. This is ok as proxy will forward
      // all the calls to the Staking impl.
      StakingGateway = await Staking.at(ContractGateway.address);
      await StakingGateway.initialize(configs[network].DOSToken, configs[network].DBToken, configs[network].RewardsVault, DOSAddressBridge.address);


      // Note: stakingRewardsValut to call approve(StakingGateway.address) as part of initialization.
    }
  });
}
