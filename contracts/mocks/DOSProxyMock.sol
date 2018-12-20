pragma solidity >= 0.4.24;

import "../DOSProxy.sol";

contract DOSProxyMock is DOSProxy{
    function initWhitelist(address[21] memory addresses) public {
        super.initWhitelist(addresses);
    }

    function getWhitelistAddress(uint idx) public view returns (address) {
        return super.getWhitelistAddress(idx);
    }

    function transferWhitelistAddress(address newWhitelistedAddr)
        public
        onlyWhitelisted
    {
        super.transferWhitelistAddress(newWhitelistedAddr);
    }

    function query(
        address from,
        uint timeout,
        string memory dataSource,
        string memory selector
    )
        public
        returns (uint)
    {
        return super.query(from, timeout, dataSource, selector);
    }

    function requestRandom(address from, uint8 mode, uint userSeed)
        public
        returns (uint)
    {
        return super.requestRandom(from, mode, userSeed);
    }

    function getMessage(bytes memory data) public view returns(bytes memory) {
        bytes memory message = abi.encodePacked(data, msg.sender);
        return message;
    }

    function validateAndVerify(
        uint8 trafficType,
        uint trafficId,
        bytes memory data,
        BN256.G1Point memory signature,
        BN256.G2Point memory grpPubKey
    )
        internal
        onlyWhitelisted
        returns (bool)
    {
        return super.validateAndVerify(trafficType, trafficId, data, signature, grpPubKey);
    }

    function getToBytes(uint x) public pure returns(bytes memory) {
        return toBytes(x);
    }

    function updateRandomness(uint[2] memory sig) public {
        super.updateRandomness(sig);
    }

    function fireRandom() public onlyWhitelisted {
        super.fireRandom();
    }

    function setPublicKey(uint x1, uint x2, uint y1, uint y2)
        public
        onlyWhitelisted
    {
        super.setPublicKey(x1, x2, y1, y2);
    }

    function uploadNodeId(uint id) public onlyWhitelisted {
        super.uploadNodeId(id);
    }

    function grouping(uint size) public onlyWhitelisted {
        super.grouping(size);
    }

    function getNodeLen() public onlyWhitelisted view returns(uint) {
        return nodeId.length;
    }

    function setGroupId(uint x1, uint x2, uint y1, uint y2) public onlyWhitelisted {
        bytes32 groupId = keccak256(abi.encodePacked(x1, x2, y1, y2));
        groups[groupId] = false;
    }

    function resetContract() public onlyWhitelisted {
        super.resetContract();
    }

}