pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./lib/BN256.sol";
import "./Ownable.sol";

contract UserContractInterface {
    // Query callback.
    function __callback__(uint, bytes memory) public;
    // Random number callback.
    function __callback__(uint, uint) public;
}

contract DOSProxy is Ownable {
    using BN256 for *;

    struct PendingRequest {
        uint requestId;
        uint handledGroupId;
        // User contract issued the query.
        address callbackAddr;
    }

    // Metadata of registered group.
    struct Group {
        uint groupId;
        BN256.G2Point groupPubKey;
        uint birthBlkN;
        uint numCurrentProcessing;
        address[] members;
    }

    // Metadata of a to-be-registered group whose members are determined already.
    struct PendingGroup {
        uint groupId;
        mapping(bytes32 => uint) pubKeyCounts;
        address[] members;
        mapping(address => bool) isMember;
    }

    uint requestIdSeed;
    // calling requestId => PendingQuery metadata
    mapping(uint => PendingRequest) PendingRequests;

    uint public refreshSystemRandomHardLimit = 60; // blocks, ~15min
    uint public groupMaturityPeriod = 11520; // blocks, ~2days
    // When regrouping, picking @gropToPick working groups, plus one group from pending nodes.
    uint public groupToPick = 2;
    uint public groupSize = 21;
    // decimal 2. TODO: should be >= 100 ???
    uint public groupingThreshold = 150;
    // Newly registered ungrouped nodes.
    address[] public pendingNodes;
    // groupId => Group
    mapping(uint => Group) public workingGroups;
    // Index:groupId
    uint[] public workingGroupIds;
    // groupId => PendingGroup
    mapping(uint => PendingGroup) pendingGroups;
    uint public numPendingGroups = 0;

    uint public lastUpdatedBlock;
    uint public lastRandomness;
    Group public lastHandledGroup;
    // TODO: Change to enum
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
    event LogInsufficientPendingNode(uint numPendingNodes);
    event LogInsufficientWorkingGroup(uint numWorkingGroups);
    event LogGrouping(uint groupId, address[] nodeId);
    event LogDuplicateWorkingGroup(uint groupId, address[] members);
    event LogAddressNotFound(uint groupId, uint[4] pubKey);
    event LogPublicKeyAccepted(uint groupId, uint[4] pubKey, uint workingGroupSize);
    event LogPublicKeySuggested(uint groupId, uint[4] pubKey, uint count, uint groupSize);
    event LogGroupDismiss(uint[4] pubKey);
    event UpdateGroupToPick(uint oldNum, uint newNum);
    event UpdateGroupSize(uint oldSize, uint newSize);
    event UpdateGroupingThreshold(uint oldThreshold, uint newThreshold);
    event UpdateGroupMaturityPeriod(uint oldPeriod, uint newPeriod);

    function setGroupToPick(uint newNum) public onlyOwner {
        require(newNum != groupToPick && newNum != 0);
        emit UpdateGroupToPick(groupToPick, newNum);
        groupToPick = newNum;
    }

    // groupSize must be an odd number.
    function setGroupSize(uint newSize) public onlyOwner {
        require(newSize != groupSize && newSize % 2 != 0);
        emit UpdateGroupSize(groupSize, newSize);
        groupSize = newSize;
    }

    function setGroupingThreshold(uint newThreshold) public onlyOwner {
        require(newThreshold != groupingThreshold && newThreshold >= 100);
        emit UpdateGroupMaturityPeriod(groupingThreshold, newThreshold);
        groupingThreshold = newThreshold;
    }

    function setGroupMaturityPeriod(uint newPeriod) public onlyOwner {
        require(newPeriod != groupMaturityPeriod && newPeriod != 0);
        emit UpdateGroupMaturityPeriod(groupMaturityPeriod, newPeriod);
        groupMaturityPeriod = newPeriod;
    }

    function getCodeSize(address addr) internal view returns (uint size) {
        assembly {
            size := extcodesize(addr)
        }
    }

    function dispatchJob() internal returns (uint idx) {
        do {
            // TODO: still keep request receipt and emit event, do not revert
            if (workingGroupIds.length == 0) revert("No active working group");

            idx = lastRandomness % workingGroupIds.length;
            Group storage group = workingGroups[workingGroupIds[idx]];
            if (block.number - group.birthBlkN < groupMaturityPeriod) {
                return idx;
            } else {
                // TODO: Deregister expired group and remove metadata
                emit LogGroupDismiss(getGroupPubKey(idx));

                // Delete expired group metadata
                delete workingGroups[workingGroupIds[idx]];
                workingGroupIds[idx] = workingGroupIds[workingGroupIds.length - 1];
                workingGroupIds.length--;
            }
        } while(true);
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
                uint idx = dispatchJob();
                Group storage grp = workingGroups[workingGroupIds[idx]];
                grp.numCurrentProcessing++;
                PendingRequests[queryId] =
                    PendingRequest(queryId, grp.groupId, from);
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
            uint idx = dispatchJob();
            Group storage grp = workingGroups[workingGroupIds[idx]];
            grp.numCurrentProcessing++;
            PendingRequests[requestId] =
                PendingRequest(requestId, grp.groupId, from);
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
        address ucAddr = PendingRequests[requestId].callbackAddr;
        if (ucAddr == address(0x0)) {
            emit LogRequestFromNonExistentUC();
            return;
        }

        Group storage handledGroup = workingGroups[PendingRequests[requestId].handledGroupId];
        if (!validateAndVerify(
                trafficType,
                requestId,
                result,
                BN256.G1Point(sig[0], sig[1]),
                handledGroup.groupPubKey,
                version))
        {
            return;
        }

        emit LogCallbackTriggeredFor(ucAddr);
        handledGroup.numCurrentProcessing--;
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
                lastHandledGroup.groupPubKey,
                version))
        {
            return;
        }
        // Update new randomness = sha3(collectively signed group signature)
        lastRandomness = uint(keccak256(abi.encodePacked(sig[0], sig[1])));
        lastUpdatedBlock = block.number;
        uint idx = dispatchJob();
        lastHandledGroup = workingGroups[workingGroupIds[idx]];
        // Signal selected off-chain clients to collectively generate a new
        // system level random number for next round.
        emit LogUpdateRandom(lastRandomness, getGroupPubKey(idx));
    }

    function handleTimeout() public {
        if (block.number - lastUpdatedBlock > refreshSystemRandomHardLimit) {
            lastRandomness = uint(keccak256(abi.encodePacked(lastRandomness, blockhash(block.number - 1))));
            lastUpdatedBlock = block.number;
            uint idx = dispatchJob();
            lastHandledGroup = workingGroups[workingGroupIds[idx]];
            // Signal off-chain clients
            emit LogUpdateRandom(lastRandomness, getGroupPubKey(idx));
        }
    }

    function getGroupPubKey(uint idx) public view returns (uint[4] memory) {
        require(idx < workingGroupIds.length, "group index out of range");

        BN256.G2Point storage pubKey = workingGroups[workingGroupIds[idx]].groupPubKey;
        return [pubKey.x[0], pubKey.x[1], pubKey.y[0], pubKey.y[1]];
    }

    function getWorkingGroupSize() public view returns (uint) {
        return workingGroupIds.length;
    }

    // TODO: restrict msg.sender from registered and staked node operator.
    // Formerly, uploadNodeId()
    function registerNewNode() public {
        pendingNodes.push(msg.sender);
        // Generate new groups from newly registered nodes and nodes from existing working group.
        if (pendingNodes.length < groupSize * groupingThreshold / 100) {
            emit LogInsufficientPendingNode(pendingNodes.length);
        } else if (workingGroupIds.length < groupToPick) {
            emit LogInsufficientWorkingGroup(workingGroupIds.length);
        } else {
            requestRandom(address(this), 1, block.number);
        }
    }

    // callback to handle re-grouping.
    // Using generated random number as random number seed.
    function __callback__(uint requestId, uint rndSeed) public {
        require(msg.sender == address(this), "Unauthenticated response");
        require(workingGroupIds.length >= groupToPick,
                "No enough working group");
        require(pendingNodes.length >= groupSize * groupingThreshold / 100,
                "No enough newly registered nodes");

        uint arrSize = groupSize * (groupToPick + 1);
        address[] memory candidates = new address[](arrSize);
        uint num = 0;
        for (uint i = 1; i <= groupToPick; i++) {
            uint idx = uint(keccak256(abi.encodePacked(rndSeed, requestId, i))) % workingGroupIds.length;
            Group storage grpToDisolve = workingGroups[workingGroupIds[idx]];
            for (uint j = 0; j < groupSize; j++) {
                candidates[num++] = grpToDisolve.members[j];
            }
            // TODO: Deregister selected group and remove Metadata
            emit LogGroupDismiss(getGroupPubKey(idx));

            // Delete expired group metadata
            delete workingGroups[workingGroupIds[idx]];
            workingGroupIds[idx] = workingGroupIds[workingGroupIds.length - 1];
            workingGroupIds.length--;
        }

        for (uint i = 0; i < pendingNodes.length; i++) {
            if (i < groupSize) {
                candidates[num++] = pendingNodes[i];
            } else {
                pendingNodes[i - groupSize] = pendingNodes[i];
            }
        }
        pendingNodes.length -= groupSize;

        shuffle(candidates, rndSeed);

        regroup(candidates);
    }

    // Shuffle a memory array using a secure random seed.
    function shuffle(address[] memory arr, uint rndSeed) private pure {
        for (uint i = arr.length - 1; i > 0; i--) {
            uint j = uint(keccak256(abi.encodePacked(rndSeed, i, arr[i]))) % (i + 1);
            address tmp = arr[i];
            arr[i] = arr[j];
            arr[j] = tmp;
        }
    }

    // Regroup a shuffled node array.
    function regroup(address[] memory candidates) internal {
        require(candidates.length == groupSize * (groupToPick + 1));

        for (uint i = 0; i < groupToPick + 1; i++) {
            uint groupId = 0;
            // Generated groupId = sha3(member 1, member 2, ..., member n)
            for (uint j = 0; j < groupSize; j++) {
                groupId = uint(keccak256(abi.encodePacked(groupId, candidates[i * groupSize + j])));
            }
            PendingGroup storage pgrp = pendingGroups[groupId];
            pgrp.groupId = groupId;
            numPendingGroups++;
            for (uint j = 0; j < groupSize; j++) {
                address member = candidates[i * groupSize + j];
                pgrp.isMember[member] = true;
                pgrp.members.push(member);
            }
            // TODO: monitor this event
            if (workingGroups[groupId].groupId != 0) {
                emit LogDuplicateWorkingGroup(groupId, pgrp.members);
            }
            emit LogGrouping(groupId, pgrp.members);
        }
    }

    // TODO: restrict msg.sender from registered and staked node operator.
    // registerGroupPubKey
    function setPublicKey(uint groupId, uint[4] memory suggestedPubKey) public {
        PendingGroup storage pgrp = pendingGroups[groupId];
        require(pgrp.groupId != 0, "No such pending group to be registered");
        require(pgrp.isMember[msg.sender], "Not from authorized group member");

        bytes32 hashedPubKey = keccak256(abi.encodePacked(
            suggestedPubKey[0], suggestedPubKey[1], suggestedPubKey[2], suggestedPubKey[3]));
        pgrp.pubKeyCounts[hashedPubKey]++;
        emit LogPublicKeySuggested(groupId, suggestedPubKey, pgrp.pubKeyCounts[hashedPubKey], groupSize);
        if (pgrp.pubKeyCounts[hashedPubKey] > groupSize / 2) {
            workingGroups[groupId] = Group(
                groupId,
                BN256.G2Point([suggestedPubKey[0], suggestedPubKey[1]], [suggestedPubKey[2], suggestedPubKey[3]]),
                block.number,
                0,
                pgrp.members);
            workingGroupIds.push(groupId);

            delete pendingGroups[groupId];
            numPendingGroups--;
            emit LogPublicKeyAccepted(groupId, suggestedPubKey, workingGroupIds.length);
        }
    }
}
