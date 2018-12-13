pragma solidity >= 0.4.24;

import "../DOSProxy.sol";

contract DOSProxyMock is DOSProxy{

    function getCodeSizeMock(address addr) public view returns (uint size) {
        return super.getCodeSize(addr);
    }

    function validateAndVerifyMock (
        uint8 trafficType,
        uint trafficId,
        string memory _data,
        uint[2] memory p1,
        uint[2][2] memory p2,
        uint8 version
    ) 
        public 
        returns (bool) {
        bytes memory data = bytes(_data);
        BN256.G1Point memory signature;
        BN256.G2Point memory grpPubKey;
        signature = BN256.G1Point(p1[0], p1[1]);
        grpPubKey = BN256.G2Point([p2[0][0], p2[0][1]], [p2[1][0], p2[1][1]]);
        return super.validateAndVerify(trafficType,trafficId,data,signature,grpPubKey,version);
    }

    function toBytesMock (uint x) public pure returns(string memory) {
        bytes memory b = super.toBytes(x);
        return string(b);
    }
}