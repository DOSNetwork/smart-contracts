const deployed = require('../deployed.json');
const stream = require('../build/contracts/Stream.json');

module.exports = {
  httpProvider: 'https://http-testnet.hecochain.com',
  coingeckoMetaSource: 'https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=ethereum,huobi-token',
  ethusdStreamAddr: deployed.hecoTestnet.CoingeckoETHUSDStream,
  streamABI: stream.abi,
  triggerMaxGas: 600000,
  heartbeat: 60 * 1000,  // 60 seconds
};
