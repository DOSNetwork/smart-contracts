const deployed = require('../deployed.json');
const stream = require('../build/contracts/Stream.json');

module.exports = {
  httpProvider: 'https://http-testnet.hecochain.com',
  coingeckoMetaSource: 'https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=ethereum,bitcoin',
  streams: [
    deployed.hecoTestnet.CoingeckoETHUSDStream,
    deployed.hecoTestnet.CoingeckoBTCUSDStream,
  ],
  streamABI: stream.abi,
  triggerMaxGas: 600000,
  heartbeat: 60 * 1000,  // 60 seconds
};
