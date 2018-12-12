pragma solidity >= 0.4.24;

import "../DOSOnChainSDK.sol";

contract DOSOnChainSDKMock is DOSOnChainSDK{
    function fromDOSProxyContractMock() public view returns (address) {
        return super.fromDOSProxyContract();
    }

    function DOSQueryMock (
        uint timeout, 
        string memory dataSource, 
        string memory selector
    ) 
        public 
        returns (uint) {
        return super.DOSQuery(timeout,dataSource,selector);
    }

    function DOSRandomMock (uint8 mode, uint seed) public returns(uint) {
        return super.DOSRandom(mode,seed);
    }
}