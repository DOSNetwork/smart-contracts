const assert = require('assert');
const BN = require('bignumber.js');
const fetch = require('node-fetch');
const jp = require('jsonpath');
const Web3 = require('web3');
const config = require('./config_heco');
const web3 = new Web3(new Web3.providers.HttpProvider(config.httpProvider));
const Feed = new web3.eth.Contract(config.feedABI, config.feedAddr);
const states = {
  "inited": false,
  "source": "",
  "selector": "",
  "windowSize": 0,
  "deviation": 0,
  "decimal": 0,
  "lastUpdated": 0,
  "lastPrice": BN(0),
}
const privateKey = '0x' + process.env.PK;


async function init(debug = false) {
  assert(privateKey.length == 66,
    "Please export hex-formatted private key into env without leading '0x'");
  states.source = await Feed.methods.source().call();
  states.selector = await Feed.methods.selector().call();
  states.windowSize = parseInt(await Feed.methods.windowSize().call());
  states.deviation = parseInt(await Feed.methods.deviation().call());
  states.decimal = parseInt(await Feed.methods.decimal().call());
  let len = parseInt(await Feed.methods.numPoints().call());
  if (len > 0) {
    let last = await Feed.methods.latestResult().call();
    states.lastPrice = BN(last._lastPrice);
    states.lastUpdated = parseInt(last._lastUpdatedTime);
  }
  states.inited = true

  if (debug) console.log(states);
}

async function query(timestamp, debug = false) {
  let resp = await fetch(config.coingeckoMetaSource);
  let respJson = await resp.json();
  let data = jp.value(respJson, states.selector);
  if (debug) {
    console.log(`+++ Time ${timestamp}, coingecko ${states.selector}: ${data}`);
  }
  return data;
}

// Returns true if Bignumber p1 is beyond the upper/lower threshold of Bignumber p0.
function deviated(p1, p0, threshold) {
  if (threshold == 0) return false;
  return p1.gt(BN(1000).plus(threshold).div(1000).times(p0)) || p1.lt(BN(1000).minus(threshold).div(1000).times(p0));
}

async function pullTriggerTx(debug) {
  let callData = Feed.methods.pullTrigger().encodeABI();
//  let estimatedGas = await Feed.methods.pullTrigger().estimateGas({gas: config.triggerMaxGas});
  let txObj = await web3.eth.accounts.signTransaction({
    to: config.feedAddr,
    data: callData,
    value: '0',
    gas: config.triggerMaxGas
  }, privateKey);
  await web3.eth.sendSignedTransaction(txObj.rawTransaction)
    .on('confirmation', async function(confirmationNumber, receipt) {
      // Fired for every confirmation up to the 12th confirmation (0-indexed). We treat 2 confirmations as finalized state.
      if (confirmationNumber == 1) {
        if (debug) {
          console.log(`+++++ tx ${receipt.transactionHash} 2 confirmations, gasUsed ${receipt.gasUsed}`);
        }
        setTimeout(heartbeat, config.heartbeat);
      }
    });
}

async function heartbeat(debug = process.env.DEBUG) {
  if (!states.inited) {
    await init(debug);
  } else {
    let last = await Feed.methods.latestResult().call();
    states.lastPrice = BN(last._lastPrice);
    states.lastUpdated = parseInt(last._lastUpdatedTime);
  }

  let now = parseInt((new Date()).getTime() / 1000);
  let data = await query(now);
  data = BN(data).times(BN(10).pow(states.decimal));
  let isDeviated = deviated(data, states.lastPrice, states.deviation);
  let isExpired = now > states.lastUpdated + states.windowSize;
  if (!isDeviated && !isExpired) {
    if (debug) console.log(`----- heartbeat ${now}, ${data} ...`);
    return setTimeout(heartbeat, config.heartbeat);
  }
  if (isDeviated) {
    console.log(`+++++ Time ${now} data ${data}, beyond +/- ${states.deviation}/1000 of last data ${states.lastPrice}, Deviation trigger`);
  } else if (isExpired) {
    console.log(`+++++ Time ${now} data ${data}, last data ${states.lastPrice} outdated (${states.lastUpdated}), Timer trigger`);
  }
  await pullTriggerTx(debug);
}

heartbeat();
