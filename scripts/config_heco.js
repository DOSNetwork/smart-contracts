const deployed = require('../deployed.json');
const stream = require('../build/contracts/Stream.json');

module.exports = {
  httpProvider: 'https://http-testnet.hecochain.com',
  coingeckoMegaSource: 'https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=bitcoin,dos-network,ethereum,huobi-token,polkadot',
  coingeckoMegaSelector: '$..usd',
  streams: [
    deployed.hecoTestnet.CoingeckoETHUSDStream,
    deployed.hecoTestnet.CoingeckoBTCUSDStream,
    deployed.hecoTestnet.CoingeckoDOTUSDStream,
    deployed.hecoTestnet.CoingeckoHTUSDStream,
    deployed.hecoTestnet.CoingeckoDOSUSDStream,
  ],
  streamABI: stream.abi,
  triggerMaxGas: 600000,
  heartbeat: 90 * 1000,  // 90 seconds
};
