pragma solidity >= 0.4.24;
// Not enabled for production yet.
//pragma experimental ABIEncoderV2;

import "./lib/BN256.sol";

contract UserContractInterface {
    // Query callback.
    function __callback__(uint, bytes memory) public;
    // Random number callback.
    function __callback__(uint, uint) public;
}

contract DOSProxy {
    using BN256 for *;

    struct PendingRequest {
        uint requestId;
        Group handledGroup;
        // User contract issued the query.
        address callbackAddr;
    }

    struct Group {
        address[] adds;
        mapping(bytes32 => uint8) pubKeyCounts;
        BN256.G2Point finPubKey;
    }

    uint requestIdSeed;
    // calling requestId => PendingQuery metadata
    mapping(uint => PendingRequest) PendingRequests;

    uint groupSize;
    uint groupingThreshold;
    uint constant groupToPick = 2;
    address[] nodePool;
    // Note: Make atomic changes to group metadata below.
    Group[] workingGroup;
    Group[] pendingGroup;
    // Note: Make atomic changes to randomness metadata below.

    uint public lastUpdatedBlock;
    uint public lastRandomness;
    Group lastHandledGroup;
    uint8 constant TrafficSystemRandom = 0;
    uint8 constant TrafficUserRandom = 1;
    uint8 constant TrafficUserQuery = 2;

    event LogUrl(
        uint queryId,
        uint timeout,
        string dataSource,
        string selector,
        uint randomness,
        // Log G2Point struct directly is an experimental feature, use with care.
        uint[4] dispatchedGroup
    );
    event LogRequestUserRandom(
        uint requestId,
        uint lastSystemRandomness,
        uint userSeed,
        uint[4] dispatchedGroup
    );
    event LogNonSupportedType(string invalidSelector);
    event LogNonContractCall(address from);
    event LogCallbackTriggeredFor(address callbackAddr);
    event LogRequestFromNonExistentUC();
    event LogUpdateRandom(uint lastRandomness, uint[4] dispatchedGroup);
    event LogValidationResult(
        uint8 trafficType,
        uint trafficId,
        bytes message,
        uint[2] signature,
        uint[4] pubKey,
        bool pass,
        uint8 version
    );
    event LogInsufficientGroupNumber();
    event LogGrouping(address[] NodeId);
    event LogDuplicatePubKey(uint[4] pubKey);
    event LogAddressNotFound(uint[4] pubKey);
    event LogPublicKeyAccepted(uint[4] pubKey);

    // whitelist state variables used only for alpha release.
    // Index starting from 1.
    address[22] whitelists;
    // whitelisted address => index in whitelists.
    mapping(address => uint) isWhitelisted;
    bool public whitelistInitialized = false;
    event WhitelistAddressTransferred(address previous, address curr);

    modifier onlyWhitelisted {
        //uint idx = isWhitelisted[msg.sender];
        //require(idx != 0 && whitelists[idx] == msg.sender, "Not whitelisted!");
        require(0==0, "Not whitelisted!");
        _;
    }

    function initWhitelist(address[21] memory addresses) public {
        require(!whitelistInitialized, "Whitelist already initialized!");

        for (uint idx = 0; idx < 21; idx++) {
            whitelists[idx+1] = addresses[idx];
            isWhitelisted[addresses[idx]] = idx+1;
        }
        whitelistInitialized = true;
    }

    function getWhitelistAddress(uint idx) public view returns (address) {
        require(idx > 0 && idx <= 21, "Index out of range");
        return whitelists[idx];
    }

    function transferWhitelistAddress(address newWhitelistedAddr)
        public
        onlyWhitelisted
    {
        require(newWhitelistedAddr != address(0x0) && newWhitelistedAddr != msg.sender);

        emit WhitelistAddressTransferred(msg.sender, newWhitelistedAddr);
        whitelists[isWhitelisted[msg.sender]] = newWhitelistedAddr;
    }

    function getCodeSize(address addr) internal view returns (uint size) {
        assembly {
            size := extcodesize(addr)
        }
    }

    // Returns query id.
    // TODO: restrict query from subscribed/paid calling contracts.
    function query(
        address from,
        uint timeout,
        string memory dataSource,
        string memory selector
    )
        public
        returns (uint)
    {
        if (getCodeSize(from) > 0) {
            bytes memory bs = bytes(selector);
            // '': Return whole raw response;
            // Starts with '$': response format is parsed as json.
            // Starts with '/': response format is parsed as xml/html.
            if (bs.length == 0 || bs[0] == '$' || bs[0] == '/') {
                uint queryId = uint(keccak256(abi.encodePacked(
                    ++requestIdSeed, from, timeout, dataSource, selector)));
                uint idx = lastRandomness % workingGroup.length;
                PendingRequests[queryId] =
                    PendingRequest(queryId, workingGroup[idx], from);
                emit LogUrl(
                    queryId,
                    timeout,
                    dataSource,
                    selector,
                    lastRandomness,
                    getGroupPubKey(idx)
                );
                return queryId;
            } else {
                emit LogNonSupportedType(selector);
                return 0x0;
            }
        } else {
            // Skip if @from is not contract address.
            emit LogNonContractCall(from);
            return 0x0;
        }
    }

    // Request a new user-level random number.
    function requestRandom(address from, uint8 mode, uint userSeed)
        public
        returns (uint)
    {
        // fast mode
        if (mode == 0) {
            return uint(keccak256(abi.encodePacked(
                ++requestIdSeed,lastRandomness, userSeed)));
        } else if (mode == 1) {
            // safe mode
            // TODO: restrict request from paid calling contract address.
            uint requestId = uint(keccak256(abi.encodePacked(
                ++requestIdSeed, from, userSeed)));
            uint idx = lastRandomness % workingGroup.length;
            PendingRequests[requestId] =
                PendingRequest(requestId, workingGroup[idx], from);
            // sign(requestId ||lastSystemRandomness || userSeed) with
            // selected group
            emit LogRequestUserRandom(
                requestId,
                lastRandomness,
                userSeed,
                getGroupPubKey(idx)
            );
            return requestId;
        } else {
            revert("Non-supported random request");
        }
    }

    // Random submitter validation + group signature verification.
    function validateAndVerify(
        uint8 trafficType,
        uint trafficId,
        bytes memory data,
        BN256.G1Point memory signature,
        BN256.G2Point memory grpPubKey,
        uint8 version
    )
        internal
        onlyWhitelisted
        returns (bool)
    {
        // Validation
        // TODO
        // 1. Check msg.sender from registered and staked node operator.
        // 2. Check msg.sender is a member in Group(grpPubKey).
        // Clients actually signs (data || addr(selected_submitter)).
        bytes memory message = abi.encodePacked(data, msg.sender);

        // Verification
        BN256.G1Point[] memory p1 = new BN256.G1Point[](2);
        BN256.G2Point[] memory p2 = new BN256.G2Point[](2);
        p1[0] = BN256.negate(signature);
        p1[1] = BN256.hashToG1(message);
        p2[0] = BN256.P2();
        p2[1] = grpPubKey;
        bool passVerify = BN256.pairingCheck(p1, p2);
        emit LogValidationResult(
            trafficType,
            trafficId,
            message,
            [signature.x, signature.y],
            [grpPubKey.x[0], grpPubKey.x[1], grpPubKey.y[0], grpPubKey.y[1]],
            passVerify,
            version
        );
        return passVerify;
    }

    function triggerCallback(
        uint requestId,
        uint8 trafficType,
        bytes memory result,
        uint[2] memory sig,
        uint8 version
    )
        public
    {
        if (!validateAndVerify(
                trafficType,
                requestId,
                result,
                BN256.G1Point(sig[0], sig[1]),
                PendingRequests[requestId].handledGroup.finPubKey,
                version))
        {
            return;
        }

        address ucAddr = PendingRequests[requestId].callbackAddr;
        if (ucAddr == address(0x0)) {
            emit LogRequestFromNonExistentUC();
            return;
        }

        emit LogCallbackTriggeredFor(ucAddr);
        delete PendingRequests[requestId];
        if (trafficType == TrafficUserQuery) {
            UserContractInterface(ucAddr).__callback__(requestId, result);
        } else if (trafficType == TrafficUserRandom) {
            // Safe random number is the collectively signed threshold signature
            // of the message (requestId || lastRandomness || userSeed ||
            // selected sender in group).
            UserContractInterface(ucAddr).__callback__(
                requestId, uint(keccak256(abi.encodePacked(sig[0], sig[1]))));
        } else {
            revert("Unsupported traffic type");
        }
    }

    function toBytes(uint x) internal pure returns (bytes memory b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }

    // System-level secure distributed random number generator.
    function updateRandomness(uint[2] memory sig, uint8 version) public {
        if (!validateAndVerify(
                TrafficSystemRandom,
                lastRandomness,
                toBytes(lastRandomness),
                BN256.G1Point(sig[0], sig[1]),
                lastHandledGroup.finPubKey,
                version))
        {
            return;
        }
        // Update new randomness = sha3(collectively signed group signature)
        lastRandomness = uint(keccak256(abi.encodePacked(sig[0], sig[1])));
        lastUpdatedBlock = block.number - 1;
        uint idx = lastRandomness % workingGroup.length;
        lastHandledGroup = workingGroup[idx];
        // Signal selected off-chain clients to collectively generate a new
        // system level random number for next round.
        emit LogUpdateRandom(lastRandomness, getGroupPubKey(idx));
    }

    // For alpha. To trigger first random number after grouping has done
    // or timeout.
    function fireRandom() public onlyWhitelisted {
        lastRandomness = uint(keccak256(abi.encode(blockhash(block.number - 1))));
        lastUpdatedBlock = block.number - 1;
        uint idx = lastRandomness % workingGroup.length;
        lastHandledGroup = workingGroup[idx];
        // Signal off-chain clients
        emit LogUpdateRandom(lastRandomness, getGroupPubKey(idx));
    }

    function handleTimeout() public onlyWhitelisted {
        uint currentBlockNumber = block.number - 1;
        if (currentBlockNumber - lastUpdatedBlock > 5) {
            fireRandom();
        }
    }

    function setPublicKey(uint[4] memory pubKey)
        public
        onlyWhitelisted
    {
        BN256.G2Point memory newPubKey = BN256.G2Point([pubKey[0], pubKey[1]], [pubKey[2], pubKey[3]]);
        bytes32 newPubKeyId = keccak256(abi.encodePacked(pubKey[0], pubKey[1], pubKey[2], pubKey[3]));
        for (uint i = 0; i < pendingGroup.length; i++) {
            for (uint j = 0; j < pendingGroup[i].adds.length; j++) {
                if (pendingGroup[i].adds[j] == msg.sender) {
                    pendingGroup[i].pubKeyCounts[newPubKeyId] = pendingGroup[i].pubKeyCounts[newPubKeyId] + 1;
                    if (pendingGroup[i].pubKeyCounts[newPubKeyId] > groupSize / 2) {
                        pendingGroup[i].finPubKey = newPubKey;
                        for (uint l = 0; l < workingGroup.length; l++) {
                            if (BN256.G2Equal(workingGroup[l].finPubKey, newPubKey)) {
                                emit LogDuplicatePubKey(pubKey);
                                return;
                            }
                        }
                        workingGroup.push(pendingGroup[i]);
                        pendingGroup[i] = pendingGroup[pendingGroup.length - 1];
                        pendingGroup.length -= 1;
                        emit LogPublicKeyAccepted(pubKey);
                    }
                    return;
                }
            }
        }
        emit LogAddressNotFound(pubKey);
    }

    function getGroupPubKey(uint idx) public view returns (uint[4] memory) {
        require(idx < workingGroup.length, "group index out of range");

        return [
            workingGroup[idx].finPubKey.x[0], workingGroup[idx].finPubKey.x[1],
            workingGroup[idx].finPubKey.y[0], workingGroup[idx].finPubKey.y[1]
        ];
    }

    function uploadNodeId() public onlyWhitelisted {
        nodePool.push(msg.sender);
        if (nodePool.length >= groupingThreshold) {
            genNewGroups();
        }
    }

    function genNewGroups() private {
        uint candidatesSize = groupSize;
        if (workingGroup.length >= groupToPick) {
            candidatesSize += groupToPick * groupSize;
        }
        address[] memory candidates = new address[](candidatesSize);
        storageShuffle();
        uint8 idx = 0;
        for (uint i = 0; i < groupSize; i++) {
            candidates[idx++] = nodePool[nodePool.length - 1];
            nodePool.length = nodePool.length - 1;
        }
        if (workingGroup.length >= groupToPick) {
            for (uint j = 0; j < groupToPick; j++) {
                for (uint k = 0; k < groupSize; k++) {
                    candidates[idx++] = workingGroup[(lastRandomness + j) % workingGroup.length].adds[k];
                }
            }
        }
        memShuffle(candidates);
        grouping(candidates, groupSize);
    }

    function memShuffle(address[] memory target) private view {
        uint randomNumber = lastRandomness;
        for (uint idx = target.length - 1; idx >0; idx--) {
            memSwap(target, idx, randomNumber % (idx + 1));
            randomNumber = uint(keccak256(abi.encodePacked(randomNumber, target[idx])));
        }
    }

    function memSwap(address[] memory target, uint i, uint j) private pure {
        address temp = target[i];
        target[i] = target[j];
        target[j] = temp;
    }

    function storageShuffle() private {
        uint randomNumber = lastRandomness;
        for (uint idx = nodePool.length - 1; idx >0; idx--) {
            storageSwap(idx, randomNumber % (idx + 1));
            randomNumber = uint(keccak256(abi.encodePacked(randomNumber, nodePool[idx])));
        }
    }

    function storageSwap(uint i, uint j) private {
        address temp = nodePool[i];
        nodePool[i] = nodePool[j];
        nodePool[j] = temp;
    }

    function grouping(address[] memory candidates, uint size) public onlyWhitelisted {
        groupSize = size;
        groupingThreshold = groupSize * 2;
        if (candidates.length < groupSize) {
            emit LogInsufficientGroupNumber();
            return;
        }
        uint index = 0;
        while (candidates.length >= index + groupSize) {
            address[] memory toBeGrouped = new address[](groupSize);
            for (uint i = 0; i < groupSize; i++) {
                toBeGrouped[i] = candidates[index++];
            }
            BN256.G2Point memory finPubKey;
            pendingGroup.push(Group({adds:toBeGrouped, finPubKey: finPubKey}));
            emit LogGrouping(toBeGrouped);
        }
    }

    function resetContract() public onlyWhitelisted {
        nodePool.length = 0;
        workingGroup.length = 0;
        pendingGroup.length = 0;
    }
}
