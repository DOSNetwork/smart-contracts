const deployed = require('../deployed.json');
const stream = require('../build/contracts/Stream.json');
const manager = require('../build/contracts/StreamsManager.json');
const mega = require('../build/contracts/MegaStream.json');

module.exports = {
  httpProvider: 'https://data-seed-prebsc-1-s1.binance.org:8545',
  coingeckoMegaSource: 'https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=binancecoin,bitcoin,dos-network,ethereum,filecoin,polkadot',
  coingeckoMegaSelector: '$..usd',
  coingeckoStreamsManagerAddr: deployed.bscTestnet.CoingeckoStreamsManager,
  managerABI: manager.abi,
  streamABI: stream.abi,
  megaStreamABI: mega.abi,
  triggerMaxGas: 800000,
  gasPriceGwei: 10,      // Gwei
  heartbeat: 60 * 1000,  // 60 seconds
};
