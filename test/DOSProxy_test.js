const DOSProxyMock = artifacts.require("DOSProxyMock");
const DOSProxy = artifacts.require("DOSProxy");

contract("DOSProxy Test", async(accounts) => {
    let proxy;
    let proxyMock;

    before(async() => {
        proxy = await DOSProxy.deployed();
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
    })

    it("Test requestRandom", async() =>{
        //how to find the userSeed
    })
})