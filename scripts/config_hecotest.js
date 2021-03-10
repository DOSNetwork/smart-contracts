const deployed = require('../deployed.json');
const stream = require('../build/contracts/Stream.json');
const manager = require('../build/contracts/StreamsManager.json');
const mega = require('../build/contracts/MegaStream.json');

module.exports = {
  httpProvider: 'https://http-testnet.hecochain.com',
  coingeckoMegaSource: 'https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=bitcoin,dos-network,ethereum,huobi-token,polkadot',
  coingeckoMegaSelector: '$..usd',
  coingeckoStreamsManagerAddr: deployed.hecoTestnet.CoingeckoStreamsManager,
  managerABI: manager.abi,
  streamABI: stream.abi,
  megaStreamABI: mega.abi,
  triggerMaxGas: 800000,
  heartbeat: 60 * 1000,  // 60 seconds
};
