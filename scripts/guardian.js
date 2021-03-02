const assert = require('assert');
const BN = require('bignumber.js');
const fetch = require('node-fetch');
const jp = require('jsonpath');
const Web3 = require('web3');
const config = require('./config_heco');
const web3 = new Web3(new Web3.providers.HttpProvider(config.httpProvider));
const privateKey = '0x' + process.env.PK;
// streams' state
const states = [];
var streamsManager = null;
var megaStream = null;

async function init(debug) {
  assert(privateKey.length == 66,
    "Please export hex-formatted private key into env without leading '0x'");

  streamsManager = new web3.eth.Contract(config.managerABI, config.coingeckoStreamsManagerAddr);
  streamsManager.address = config.coingeckoStreamsManagerAddr;
  let sortedStreams = await streamsManager.methods.sortedStreams().call();
  if (sortedStreams.length == 0) {
    console.log('@@@@@@ No stream to watch, exit!');
    process.exit(1);
  }

  let megaStreamAddr = await streamsManager.methods._streams(0).call();
  megaStream = new web3.eth.Contract(config.megaStreamABI, megaStreamAddr);
  megaStream.address = megaStreamAddr;
  megaStream.decimal = await megaStream.methods.decimal().call();

  for (let i = 0; i < sortedStreams.length; i++) {
    let stream = new web3.eth.Contract(config.streamABI, sortedStreams[i]);
    stream.address = sortedStreams[i];
    let state = {
      stream: stream,
      source: await stream.methods.source().call(),
      selector: await stream.methods.selector().call(),
      windowSize: parseInt(await stream.methods.windowSize().call()),
      deviation: parseInt(await stream.methods.deviation().call()),
      decimal: parseInt(await stream.methods.decimal().call()),
      lastUpdated: 0,
      lastPrice: BN(0),
    }
    let len = parseInt(await stream.methods.numPoints().call());
    if (len > 0) {
      let last = await stream.methods.latestResult().call();
      state.lastPrice = BN(last._lastPrice);
      state.lastUpdated = parseInt(last._lastUpdatedTime);
    }
    states.push(state);
  }
  if (debug) console.log('+++++ streams inited ...');
}

async function sync() {
  for (let i = 0; i < states.length; i++) {
    states[i].deviation = parseInt(await states[i].stream.methods.deviation().call());
    let last = await states[i].stream.methods.latestResult().call();
    states[i].lastPrice = BN(last._lastPrice);
    states[i].lastUpdated = parseInt(last._lastUpdatedTime);
  }
}

// Normalize selector string to equivalent format in case of special characters.
// e.g. '$.huobi-token.usd' => '$["huobi-token"]["usd"]'
function normalizeSelector(selector) {
  if (selector.indexOf('-') == -1) return selector;
  return selector
    .split('.')
    .map((val, i) => {
      if (i == 0) return val;
      return '[\"' + val + '\"]';
    })
    .join('');
}

// Sort response json by object keys. This is to normalize the jsonpath
// behavior between client software and this guardian bot.
function normalizeResponseJson(respJson) {
  return Object.keys(respJson).sort().reduce(function (result, key) {
    result[key] = respJson[key];
    return result;
  }, {});
}

async function queryCoingeckoStreamsData(debug = false) {
  let ret = [];
  let resp = await fetch(config.coingeckoMegaSource);
  let respJson = await resp.json();
  for (let i = 0; i < states.length; i++) {
    let data = jp.value(respJson, normalizeSelector(states[i].selector));
    data = BN(data).times(BN(10).pow(states[i].decimal));
    ret.push(data);
    if (debug) {
      console.log(`+++++ coingecko ${states[i].selector}: ${data}`);
    }
  }
  return ret;
}

async function queryCoingeckoMegaData(megaDecimal) {
  let resp = await fetch(config.coingeckoMegaSource);
  let respJson = await resp.json();
  respJson = normalizeResponseJson(respJson);
  let data = jp.query(respJson, config.coingeckoMegaSelector);
  return data.map((val) => {
    return BN(val).times(BN(10).pow(megaDecimal))
  });
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

async function pullTriggerStream(state, debug) {
  let callData = state.stream.methods.pullTrigger().encodeABI();
  //  let estimatedGas = await state.stream.methods.pullTrigger().estimateGas({gas: config.triggerMaxGas});
  let txObj = await web3.eth.accounts.signTransaction({
    to: state.stream.address,
    data: callData,
    value: '0',
    gas: config.triggerMaxGas
  }, privateKey);
  await web3.eth.sendSignedTransaction(txObj.rawTransaction)
    .on('confirmation', async function(confirmationNumber, receipt) {
      // Fired for every confirmation up to the 12th confirmation (0-indexed). We treat 2 confirmations as finalized state.
      if (confirmationNumber == 1) {
        if (debug) {
          console.log(`+++++ ${state.selector} tx ${receipt.transactionHash} 2 confirmations, gasUsed ${receipt.gasUsed}`);
        }
      }
    })
    .on('error', async function(err) {
      console.error(err);
    });
}

async function pullTriggerMega(debug) {
  let callData = megaStream.methods.pullTrigger().encodeABI();
  //  let estimatedGas = await state.stream.methods.pullTrigger().estimateGas({gas: config.triggerMaxGas});
  let txObj = await web3.eth.accounts.signTransaction({
    to: megaStream.address,
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
      }
    })
    .on('error', async function(err) {
      console.error(err);
    });
}

async function heartbeatStreams(debug = process.env.DEBUG) {
  if (states.length == 0) {
    await init(debug);
  } else {
    await sync();
  }

  let data = await queryCoingeckoStreamsData();
  for (let i = 0; i < states.length; i++) {
    let now = parseInt((new Date()).getTime() / 1000);
    let now_str = (new Date()).toTimeString().split(' ')[0];
    if (i == 0 && debug) console.log(`----- heartbeatStreams ${now_str} ...`);
    let isDeviated = deviated(data[i], states[i].lastPrice, states[i].deviation);
    let isExpired = now > states[i].lastUpdated + states[i].windowSize;
    if (!isDeviated && !isExpired) {
      continue;
    } else if (isDeviated) {
      console.log(`+++++ Stream ${states[i].selector} ${now_str} d(${data[i]}), beyond last data (${states[i].lastPrice}) +/- ${states[i].deviation}/1000, Deviation trigger`);
    } else if (isExpired) {
      console.log(`+++++ Stream ${states[i].selector} ${now_str} d(${data[i]}), last data (${states[i].lastPrice}) outdated, Timer trigger`);
    }
    await pullTriggerStream(states[i], debug);
  }
  setTimeout(heartbeatStreams, config.heartbeatStreams);
}

async function heartbeatMega(debug = process.env.DEBUG) {
  if (states.length == 0) {
    await init(debug);
  } else {
    await sync();
  }

  let data = await queryCoingeckoMegaData(megaStream.decimal);
  if (data.length != states.length) {
    console.log('@@@@@ Mega data & Mega query / selector mismatch, exit!');
    process.exit(1);
  }

  let trigger = false;
  for (let i = 0; i < states.length; i++) {
    let now = parseInt((new Date()).getTime() / 1000);
    let now_str = (new Date()).toTimeString().split(' ')[0];
    if (i == 0 && debug) console.log(`----- heartbeatMega ${now_str} ...`);
    let isDeviated = deviated(data[i], states[i].lastPrice, states[i].deviation);
    let isExpired = now > states[i].lastUpdated + states[i].windowSize;
    if (!isDeviated && !isExpired) {
      continue;
    } else if (isDeviated) {
      console.log(`+++++ Mega Stream[${i}] ${states[i].selector} ${now_str} d(${data[i]}), beyond last data (${states[i].lastPrice}) +/- ${states[i].deviation}/1000, Deviation trigger`);
      trigger = true;
    } else if (isExpired) {
      console.log(`+++++ Mega Stream[${i}] ${states[i].selector} ${now_str} d(${data[i]}), last data (${states[i].lastPrice}) outdated, Timer trigger`);
      trigger = true;
    }
  }
  if (trigger) {
    await pullTriggerMega(debug);
    setTimeout(heartbeatMega, config.heartbeatMega);
  } else {
    setTimeout(heartbeatMega, config.heartbeatStreams);
  }
}

// heartbeatStreams();

heartbeatMega();
