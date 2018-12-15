const DOSProxyMock = artifacts.require("DOSProxyMock");
const DOSProxy = artifacts.require("DOSProxy");

contract("DOSProxy Test", async(accounts) => {
    let proxy;
    let proxyMock;

    before(async() => {
        proxy = await DOSProxy.deployed({from:accounts[0]});
        proxyMock = await DOSProxyMock.new();
    })

    it("Test initWhitelist", async() => {
        let addresses = new Array(21);
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
        let idx0 = 1;
        let address0 = accounts[idx0-1];
        let idx1 = 21;
        let address1 = accounts[idx1-1];
        let result0 = await proxy.getWhitelistAddress.call(idx0);
        assert.equal(result0.toString(10),address0.toString(10),"can not equal");
        let result1 = await proxy.getWhitelistAddress.call(idx1);
        assert.equal(result1.toString(10),address1.toString(10),"can not equal");
    })

    it("Test transferWhitelistAddress", async() => {
        let newWhitelistedAddr = accounts[21];
        await proxy.transferWhitelistAddress(newWhitelistedAddr);
        let result = await proxy.getWhitelistAddress.call(1);
        assert.equal(result.toString(10), newWhitelistedAddr.toString(10),"can not transfer");
    })

    it("Test query", async() => {
        //how to find the example about datasource&selector
        //queryId = DOSQuery(30, "https://api.coinbase.com/v2/prices/ETH-USD/spot", "$.data.amount");
        let from = accounts[0];
        let invalidFrom = accounts[1];
        let timeout = 30;
        let dataSource = "https://api.coinbase.com/v2/prices/ETH-USD/spot";
        let selector = "$.data.amount";
        let invalidSelector = "*data.amount";
        // let queryId = await proxy.query(from,timeout,dataSource,selector);
        //???????????????????????????????? console.log(queryId);
        let invalidContract = await proxy.query.call(invalidFrom,timeout,dataSource,selector);
        let invalidId = await proxy.query.call(from,timeout,dataSource,invalidSelector);
        //assert.equal(queryId.toString(10),0,"fail to generate query id");
        assert.equal(invalidContract,0,"fail to generate query id");
        assert.equal(invalidId,0,"fail to generate query id");
    })

    it("Test requestRandom", async() =>{
        //how to find the userSeed
        let from = accounts[0];
    })
})