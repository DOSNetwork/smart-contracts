const DOSOnChainSDKMock = artifacts.require("DOSOnChainSDKMock");

contract("DOSOnChainSDK Test", async() => {
    let dosOnChainSDK;

    before (async () => {
        dosOnChainSDK = await DOSOnChainSDKMock.new();
    })

    it("Test fromDOSProxyContract()", async() => {
        let proxyAddress = await dosOnChainSDK.fromDOSProxyContractMock.call();
        assert.equal(proxyAddress, 0xe987926A226932DFB1f71FA316461db272E05317, "get Proxy address");
    });

    it("Test DOSQueryMock()", async() => {

    })
})