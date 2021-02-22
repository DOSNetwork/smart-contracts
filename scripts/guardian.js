const assert = require('assert');
const BN = require('bignumber.js');
const fetch = require('node-fetch');
const jp = require('jsonpath');
const Web3 = require('web3');
const config = require('./config_heco');
const web3 = new Web3(new Web3.providers.HttpProvider(config.httpProvider));
const Stream = new web3.eth.Contract(config.streamABI, config.ethusdStreamAddr);
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
  states.source = await Stream.methods.source().call();
  states.selector = await Stream.methods.selector().call();
  states.windowSize = parseInt(await Stream.methods.windowSize().call());
  states.deviation = parseInt(await Stream.methods.deviation().call());
  states.decimal = parseInt(await Stream.methods.decimal().call());
  let len = parseInt(await Stream.methods.numPoints().call());
  if (len > 0) {
    let last = await Stream.methods.latestResult().call();
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

function sleep(ms) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      resolve(ms)
    }, ms)
  })
}

async function pullTriggerTx(debug) {
  let callData = Stream.methods.pullTrigger().encodeABI();
//  let estimatedGas = await Stream.methods.pullTrigger().estimateGas({gas: config.triggerMaxGas});
  let txObj = await web3.eth.accounts.signTransaction({
    to: config.ethusdStreamAddr,
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
    })
    .on('error', async function(err) {
      console.error(err);
      setTimeout(heartbeat, config.heartbeat);
    });
}

async function heartbeat(debug = process.env.DEBUG) {
  if (!states.inited) {
    await init(debug);
  } else {
    let last = await Stream.methods.latestResult().call();
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
