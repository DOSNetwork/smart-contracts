const deployed = require('../deployed.json');
const feed = require('../build/contracts/Feed.json');

module.exports = {
  httpProvider: 'https://http-testnet.hecochain.com',
  coingeckoMetaSource: 'https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=ethereum,huobi-token',
  feedAddr: deployed.hecoTestnet.FeedV1,
  feedABI: feed.abi,
  triggerMaxGas: 600000,
  heartbeat: 40 * 1000,  // 40 seconds
};
