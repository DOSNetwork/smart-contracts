const DOSProxy = artifacts.require("DOSProxyMock");
const BN256Mock = artifacts.require("BN256Mock");
const BigNumber = require('bignumber.js');
contract("DOSProxy Test", async(accounts) => {
    let proxyinstance;
    let bn256;

    DOSProxy.deployed().then(instance => {
        const events = instance.allEvents();
        events.watch(function(error, result) {
            if (!error) {
                console.log("instance event " + result.event + " detected: ");
                if (result.event == "LogUrl") {
                    console.log("   queryId: " + result.args.queryId);
                    console.log("   timeout: " + result.args.timeout);
                    console.log("   dataSource: " + result.args.dataSource);
                    console.log("   selector: " + result.args.selector);
                    console.log("   randomness: " + result.args.randomness);
                    console.log("   dispatchedGroup: " + result.args.dispatchedGroup);
                } else if (result.event == "LogNonSupportedType") {
                    console.log("   invalidSelector: " + result.args.invalidSelector);
                } else if (result.event == "LogNonContractCall") {
                    console.log("   from: " + result.args.from);
                } else if (result.event == "LogRequestUserRandom") {
                    console.log("   requestId: " + result.args.requestId);
                    console.log("   lastSystemRandomness: " + result.args.lastSystemRandomness);
                    console.log("   userSeed: " + result.args.userSeed);
                    console.log("   dispatchedGroup: " + result.args.dispatchedGroup);
                } else if (result.event == "LogCallbackTriggeredFor") {
                    console.log("   callbackAddr: " + result.args.callbackAddr);
                } else if (result.event == "LogRequestFromNonExistentUC") {
                    console.log("   LogRequestFromNonExistentUC");
                } else if (result.event == "LogUpdateRandom") {
                    console.log("   lastRandomness: " + result.args.lastRandomness);
                    console.log("   dispatchedGroup: " + result.args.dispatchedGroup);
                } else if (result.event == "LogValidationResult") {
                    console.log("   trafficType: " + result.args.trafficType);
                    console.log("   trafficId: " + result.args.trafficId);
                    console.log("   message: " + result.args.message);
                    console.log("   signature: " + result.args.signature);
                    console.log("   pubKey: " + result.args.pubKey);
                    console.log("   pass: " + result.args.pass);
                    console.log("   version: " + result.args.version);
                } else if (result.event == "LogInsufficientGroupNumber") {
                    console.log("   invalidSelector");
                } else if (result.event == "LogGrouping") {
                    console.log("   NodeId: " + result.args.NodeId);
                } else if (result.event == "LogPublicKeyAccepted") {
                    console.log("   x1: " + result.args.x1);
                    console.log("   x2: " + result.args.x2);
                    console.log("   y1: " + result.args.y1);
                    console.log("   y2: " + result.args.y2);
                } else if (result.event == "WhitelistAddressTransferred") {
                    console.log("   previous: " + result.args.previous);
                    console.log("   curr: " + result.args.curr);
                } else {
                    console.log(result);
                }
            } else {
                console.log("Error occurred while watching events.");
            }
        });
        proxyinstance = instance;
    });

    before(async () => {
        bn256 = await BN256Mock.new();
      })

    it("Test initWhitelist", async() => {
        //!!!pay attention: create 21 local address first
        let proxy;
        proxy = await proxyinstance;
        let addresses = new Array(22);
        for(let i = 0; i < 21; i++) {
            addresses[i] = accounts[i];
            //console.log(addresses[i]);
            //web3.personal.newAccount()
            //web3.eth.accounts
            //use these commands to make sure that there are enough accounts in your net
        }
        await proxy.initWhitelist(addresses);
        let result = await proxy.whitelistInitialized.call();
        assert.equal(result, true,"Whitelist already initialized");
    })

    it("Test getWhitelistAddress", async() => {
        //need to initWHitelist, or the value equals zero;
        let proxy;
        proxy = await proxyinstance;
        let idx0 = 1;
        let address0 = accounts[idx0-1];
        let idx21 = 21;
        let address1 = accounts[idx21-1];
        let result0 = await proxy.getWhitelistAddress.call(idx0);
        assert.equal(result0.toString(10),address0.toString(10),"can not equal");
        let result1 = await proxy.getWhitelistAddress.call(idx21);
        assert.equal(result1.toString(10),address1.toString(10),"can not equal");
    })

    it("Test query", async() => {
        let proxy;
        proxy = await proxyinstance;
        await proxy.setPublicKey(1,2,2,1);
        let from = proxy.address;
        let invalidFrom = accounts[1];
        let timeout = 30;
        let dataSource = "https://api.coinbase.com/v2/prices/ETH-USD/spot";
        let selector = "$.data.amount";
        let invalidSelector = "*data.amount";   
        let queryId1 = await proxy.query(from,timeout,dataSource,selector);
        let queryId2 = await proxy.query(from,timeout,dataSource,selector);
        await proxy.query(invalidFrom,timeout,dataSource,selector);
        await proxy.query(from,timeout,dataSource,invalidSelector);
        assert.equal(queryId1 == queryId2,false,"fail to generate query id");
    })

    it("Test requestRandom", async() =>{
        let proxy;
        proxy = await proxyinstance;
        await proxy.resetContract();
        await proxy.setGroupId(1,2,2,1);
        let from = proxy.address;
        let fastMode = 0;
        let safeMode = 1;
        let userSeed = 100;
        let fastResult0 = await proxy.requestRandom(from, fastMode, userSeed);
        let fastResult1 = await proxy.requestRandom(from, fastMode, userSeed);
        await proxy.setPublicKey(1,2,2,1);
        let safeResult0 = await proxy.requestRandom(from, safeMode, userSeed);
        let safeResult1 = await proxy.requestRandom(from, safeMode, userSeed);
        assert.equal(fastResult0 == fastResult1, false, "fail to generate requestID in fast mode");
        assert.equal(safeResult0 == safeResult1, false, "fail to generate requestID in safe mode");
    })
    
    it ("Test updateRandomness", async() => {
        let proxy;
        proxy = await proxyinstance;
        await proxy.resetContract();
        await proxy.setGroupId(1,2,2,1);
        await proxy.grouping(3);
        let SK = new BigNumber('0x250ebf796264728de1dc24d208c4cec4f813b1bcc2bb647ac8cf66206568db03');
        let PK = [
            [
              new BigNumber('0x25d7caf90ac28ba3cd8a96aff5c5bf004fc16d9bdcc2cead069e70f783397e5b'),
              new BigNumber('0x04ef63f195409b451179767b06673758e621d9db71a058231623d1cb2e594460')
            ],
            [
              new BigNumber('0x15729e3589dcb871cd46eb6774388aad867521dc07d1e0c0d9c99f444f93ca53'),
              new BigNumber('0x15db87d74b02df70d62f7f8afe5811ade35ca08bdb2308b4153624083fcf580e')
            ]
          ];
        await proxy.setPublicKey(PK[0][0],PK[0][1],PK[1][0],PK[1][1]);
        await proxy.setPublicKey(PK[0][0],PK[0][1],PK[1][0],PK[1][1]);
        await proxy.fireRandom();
        let rand = await proxy.lastRandomness.call();
        let data = await proxy.getToBytes.call(rand);
        let msg = await proxy.getMessage.call(data);
        let hashed_msg = await bn256.hashToG1.call(msg);
        let sig = await bn256.scalarMul.call(hashed_msg, SK);
        await proxy.updateRandomness(sig);
    })

    it ("Test fireRandom", async() => {
        let proxy;
        proxy = await proxyinstance;
        await proxy.resetContract();
        await proxy.setGroupId(1,2,2,1);
        await proxy.grouping(3);
        await proxy.setPublicKey(1,2,2,1);
        await proxy.setPublicKey(1,2,2,1);
        await proxy.fireRandom();
    })

    it ("Test grouping & uploadNodeId", async() => {
        let proxy;
        proxy = await proxyinstance;
        await proxy.uploadNodeId(1);
        await proxy.uploadNodeId(3);
        await proxy.uploadNodeId(5);
        await proxy.uploadNodeId(7);
        await proxy.grouping(3);
        let result = await proxy.getNodeLen.call();
        assert.equal(result.toNumber(), 1,"groupsize = 3");
    })

    it("Test transferWhitelistAddress", async() => {
        //need to initWhitelist, or the value equals zero;
        let proxy;
        proxy = await proxyinstance;
        let newWhitelistedAddr = accounts[21];
        await proxy.transferWhitelistAddress(newWhitelistedAddr);
        let result = await proxy.getWhitelistAddress.call(1);
        assert.equal(result.toString(10), newWhitelistedAddr.toString(10),"can not transfer");
    })

    it('延迟结束，为event捕获预留时间函数',() => {
        var now = new Date().getTime();
        while(new Date().getTime() < now + 5000){ /* do nothing */ }
    });

    after(() => {
        console.log("Test finished.");
    });
})