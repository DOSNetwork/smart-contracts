pragma solidity >= 0.4.24;

import "../DOSProxy.sol";

contract DOSOnChainSDKMock is DOSProxy{
    function getCodeSizeMock(address addr) public view returns (uint size) {
        return getCodeSize(addr);
    }

    function validateAndVerifyMock (
        uint8 trafficType,
        uint trafficId,
        bytes memory data,
        uint[2] memory p1,
        uint[2][2] memory p2,
        uint8 version
    ) 
        public 
        returns (bool) {
        BN256.G1Point memory signature;
        BN256.G2Point memory grpPubKey;
        signature = BN256.G1Point(p1[0], p1[1]);
        grpPubKey = BN256.G2Point([p2[0][0], p2[0][1]], [p2[1][0], p2[1][1]]);
        return validateAndVerify(trafficType,trafficId,data,signature,grpPubKey,version);
    }

    function toBytesMock (uint x) public pure returns(bytes memory b) {
        return toBytes(x);
    }
}