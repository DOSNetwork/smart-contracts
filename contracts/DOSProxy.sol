pragma solidity ^0.5.0;
// Do not use in production
// pragma experimental ABIEncoderV2;

import "./lib/BN256.sol";
import "./Ownable.sol";

contract UserContractInterface {
    // Query callback.
    function __callback__(uint, bytes memory) public;
    // Random number callback.
    function __callback__(uint, uint) public;
}

contract CommitRevealInterface {
    function startCommitReveal(uint, uint, uint, uint) public returns(uint);
    function getRandom(uint) public returns(uint);
}

contract DOSProxy is Ownable {
    using BN256 for *;

    // Metadata of pending request.
    struct PendingRequest {
        uint requestId;
        BN256.G2Point handledGroupPubKey;
        // Calling contract who issues the request.
        address callbackAddr;
    }

    // Metadata of registered group.
    struct Group {
        uint groupId;
        BN256.G2Point groupPubKey;
        uint birthBlkN;
        address[] members;
    }

    // Metadata of a to-be-registered group whose members are determined already.
    struct PendingGroup {
        uint groupId;
        mapping(bytes32 => uint) pubKeyCounts;
        address[] members;
        mapping(address => bool) isMember;
    }

    // Metadata of registered node.
    struct Node {
        // Key: working groupId node is in
        mapping(uint => bool) inGroups;
        // Number of working groups node is in
        uint inGroupCount;
    }

    uint requestIdSeed;
    // calling requestId => PendingQuery metadata
    mapping(uint => PendingRequest) PendingRequests;

    uint public refreshSystemRandomHardLimit = 60; // blocks, ~15min
    uint public groupMaturityPeriod = 11520; // blocks, ~2days
    // When regrouping, picking @gropToPick working groups, plus one group from pending nodes.
    uint public groupToPick = 2;
    uint public groupSize = 21;
    // decimal 2.
    uint public groupingThreshold = 150;
    //For bootstrapping
    uint public bootstrapCommitDuration = 3;
    uint public bootstrapRevealDuration = 3;
    uint public bootstrapRevealThreshold = 3;
    uint public bootstrapRound = 0;

    // Commit-Reveal library address
    address public commitrevealLib = address(0x0);

    // Newly registered ungrouped nodes.
    address[] public pendingNodes;
    mapping(address => bool) pendingNodeMap;
    // node => working groupIds node is in.
    mapping(address => Node) workingNodeMap;
    // groupId => Group
    mapping(uint => Group) workingGroups;
    // Index:groupId
    uint[] public workingGroupIds;
    // groupId => PendingGroup
    mapping(uint => PendingGroup) pendingGroups;
    uint public numPendingGroups = 0;

    uint public lastUpdatedBlock;
    uint public lastRandomness;
    Group lastHandledGroup;

    enum TrafficType {
        SystemRandom,
        UserRandom,
        UserQuery
    }

    event LogUrl(
        uint queryId,
        uint timeout,
        string dataSource,
        string selector,
        uint randomness,
        uint dispatchedGroupId,
        // TODO: Sync with client to remove this event argument.
        uint[4] dispatchedGroup
    );
    event LogRequestUserRandom(
        uint requestId,
        uint lastSystemRandomness,
        uint userSeed,
        uint dispatchedGroupId,
        // TODO: Sync with client to remove this event argument.
        uint[4] dispatchedGroup
    );
    event LogNonSupportedType(string invalidSelector);
    event LogNonContractCall(address from);
    event LogCallbackTriggeredFor(address callbackAddr);
    event LogRequestFromNonExistentUC();
    event LogUpdateRandom(uint lastRandomness, uint dispatchedGroupId,uint[4] dispatchedGroup);
    event LogValidationResult(
        uint8 trafficType,
        uint trafficId,
        bytes message,
        uint[2] signature,
        uint[4] pubKey,
        uint8 version,
        bool pass
    );
    event LogInsufficientPendingNode(uint numPendingNodes);
    event LogInsufficientWorkingGroup(uint numWorkingGroups);
    event LogGrouping(uint groupId, address[] nodeId);
    event LogDuplicateWorkingGroup(uint groupId, address[] members);
    event LogAddressNotFound(uint groupId, uint[4] pubKey);
    event LogPublicKeyAccepted(uint groupId, uint[4] pubKey, uint workingGroupSize);
    event LogPublicKeySuggested(uint groupId, uint[4] pubKey, uint count, uint groupSize);
    event LogGroupDissolve(uint groupId, uint[4] pubKey);
    event LogRegisteredNewPendingNode(address node);
    event LogGroupingInitiated(uint pendingNodePool, uint groupsize, uint groupingthreshold);
    event UpdateGroupToPick(uint oldNum, uint newNum);
    event UpdateGroupSize(uint oldSize, uint newSize);
    event UpdateGroupingThreshold(uint oldThreshold, uint newThreshold);
    event UpdateGroupMaturityPeriod(uint oldPeriod, uint newPeriod);
    event Bite(uint blkNum, address indexed guardian);

    function getLastHandledGroup() public view returns(uint, uint[4] memory, uint, address[] memory) {
        return (
            lastHandledGroup.groupId,
            getGroupPubKey(lastHandledGroup.groupId),
            lastHandledGroup.birthBlkN,
            lastHandledGroup.members
        );
    }

    function getWorkingGroupById(uint groupId) public view returns(uint, uint[4] memory, uint, address[] memory) {
        return (
            workingGroups[groupId].groupId,
            getGroupPubKey(groupId),
            workingGroups[groupId].birthBlkN,
            workingGroups[groupId].members
        );
    }

    function setCommitrevealLib(address lib) public onlyOwner {
        require(commitrevealLib == address(0x0), "Library address already set");
        commitrevealLib = lib;
    }

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

    function setBootstrapCommitDuration(uint newCommitDuration) public onlyOwner {
        require(newCommitDuration != bootstrapCommitDuration && newCommitDuration != 0);
        bootstrapCommitDuration = newCommitDuration;
    }

    function setBootstrapRevealDuration(uint newRevealDuration) public onlyOwner {
        require(newRevealDuration != bootstrapRevealDuration && newRevealDuration != 0);
        bootstrapRevealDuration = newRevealDuration;
    }

    function getCodeSize(address addr) internal view returns (uint size) {
        assembly {
            size := extcodesize(addr)
        }
    }

    function dispatchJobCore(TrafficType trafficType, uint pseudoSeed) private returns(uint idx) {
        uint rnd = uint(keccak256(abi.encodePacked(trafficType, pseudoSeed, lastRandomness)));
        do {
            //TODO: Once it goes to this state,DOSProxy can't generate a new grooup.
            //Because generate a new group need to request a random first that will be reverted.
            //if (workingGroupIds.length == 0) revert("No active working group");
            //It should save this request and trigger a bootstrap process
            //Workaroud: Don't revert and don't dissolve remaining group
            if (workingGroupIds.length == (groupToPick + 1)) {
                idx = rnd % workingGroupIds.length;
                return idx;
            }
            idx = rnd % workingGroupIds.length;
            Group storage group = workingGroups[workingGroupIds[idx]];
            if (block.number - group.birthBlkN < groupMaturityPeriod) {
                return idx;
            } else {
                dissolveWorkingGroup(idx);
            }
        } while(true);
    }

    function dispatchJob(TrafficType trafficType, uint pseudoSeed) internal returns(uint) {
        if (block.number - lastUpdatedBlock > refreshSystemRandomHardLimit) {
            kickoffRandom();
        }
        return dispatchJobCore(trafficType, pseudoSeed);
    }

    function kickoffRandom() internal {
        lastUpdatedBlock = block.number;
        uint idx = dispatchJobCore(TrafficType.SystemRandom, uint(blockhash(block.number - 1)));
        lastHandledGroup = workingGroups[workingGroupIds[idx]];
        // Signal off-chain clients
        emit LogUpdateRandom(lastRandomness, lastHandledGroup.groupId, getGroupPubKey(idx));
    }

    /// @notice Caller ensures no index overflow.
    function dissolveWorkingGroup(uint idx) internal {
        /// Deregister expired working group and remove metadata.
        Group storage grp = workingGroups[workingGroupIds[idx]];
        for (uint i = 0; i < grp.members.length; i++) {
            delete workingNodeMap[grp.members[i]].inGroups[grp.groupId];
            if (--workingNodeMap[grp.members[i]].inGroupCount == 0) {
                // Put member node into pendingNodes pool once it doesn't belong to any working group.
                // Notice: Guardian may need to signal group formation.
                pendingNodes.push(grp.members[i]);
                pendingNodeMap[grp.members[i]] = true;
                emit LogRegisteredNewPendingNode(grp.members[i]);
            }
        }
        emit LogGroupDissolve(grp.groupId, getGroupPubKey(idx));

        delete workingGroups[workingGroupIds[idx]];
        workingGroupIds[idx] = workingGroupIds[workingGroupIds.length - 1];
        workingGroupIds.length--;
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
                uint idx = dispatchJob(TrafficType.UserQuery, queryId);
                Group storage grp = workingGroups[workingGroupIds[idx]];
                PendingRequests[queryId] =
                    PendingRequest(queryId, grp.groupPubKey, from);
                emit LogUrl(
                    queryId,
                    timeout,
                    dataSource,
                    selector,
                    lastRandomness,
                    grp.groupId,
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
            uint idx = dispatchJob(TrafficType.UserRandom, requestId);
            Group storage grp = workingGroups[workingGroupIds[idx]];
            PendingRequests[requestId] =
                PendingRequest(requestId, grp.groupPubKey, from);
            // sign(requestId ||lastSystemRandomness || userSeed ||
            // selected sender in group)
            emit LogRequestUserRandom(
                requestId,
                lastRandomness,
                userSeed,
                grp.groupId,
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
            version,
            passVerify
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

        if (!validateAndVerify(
                trafficType,
                requestId,
                result,
                BN256.G1Point(sig[0], sig[1]),
                PendingRequests[requestId].handledGroupPubKey,
                version))
        {
            return;
        }

        emit LogCallbackTriggeredFor(ucAddr);
        delete PendingRequests[requestId];
        if (trafficType == uint8(TrafficType.UserQuery)) {
            UserContractInterface(ucAddr).__callback__(requestId, result);
        } else if (trafficType == uint8(TrafficType.UserRandom)) {
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
                uint8(TrafficType.SystemRandom),
                lastRandomness,
                toBytes(lastRandomness),
                BN256.G1Point(sig[0], sig[1]),
                lastHandledGroup.groupPubKey,
                version))
        {
            return;
        }
        // Update new randomness = sha3(collectively signed group signature)
        // TODO: include and test with blockhash.
        lastRandomness = uint(keccak256(abi.encodePacked(sig[0], sig[1])));
        lastUpdatedBlock = block.number;
    }

    /// Guardian node functions
    // Formerly "handleTimeout()"
    // TODO: Tune guardian signal algorithm.
    // TODO: Reward guardian nodes.
    /// @dev Guardian signals expiring system randomness and kicks off distributed random engine again.
    ///  Anyone including but not limited to DOS client node can be a guardian and claim rewards.
    function signalRandom() public {
        require(block.number - lastUpdatedBlock > refreshSystemRandomHardLimit,
                "Not right time to trigger random yet");

        kickoffRandom();
        emit Bite(block.number, msg.sender);
    }
    // TODO: Reward guardian nodes.
    /// @dev Guardian signals to dissolve expired working group and claim for guardian rewards.
    /// @param idx The index in workingGroupIds array.
    function signalDissolve(uint idx) public {
        require(idx < workingGroupIds.length, "Working groups index overflow");
        require(block.number - workingGroups[workingGroupIds[idx]].birthBlkN > groupMaturityPeriod,
                "Not right time to signal dissolve yet");

        dissolveWorkingGroup(idx);
        emit Bite(block.number, msg.sender);
    }
    // TODO: Reward guardian nodes.
    /// @dev Guardian signals to trigger group formation when there're enough pending nodes.
    ///  If there aren't enough working groups to choose to dossolve, probably a new bootstrap is needed.
    function signalGroupFormation() public {
        require(pendingNodes.length >= groupSize * groupingThreshold / 100, "Not enough pending nodes");

        if (workingGroupIds.length >= groupToPick) {
            requestRandom(address(this), 1, block.number);
            emit LogGroupingInitiated(pendingNodes.length, groupSize, groupingThreshold);
        } else {
            require(bootstrapRound == 0, "Invalid bootstrap round");
            bootstrapRound = CommitRevealInterface(commitrevealLib).startCommitReveal(now+1, bootstrapCommitDuration, bootstrapRevealDuration, bootstrapRevealThreshold);
        }
    }
    // TODO: Reward guardian nodes.
    function signalBootstrap(uint _cid) public {
        require(bootstrapRound == _cid, "Not in bootstrap phase");
        require(pendingNodes.length >= groupSize * (groupToPick + 1), "Not enough nodes to bootstrap");

        // Reset
        bootstrapRound = 0;

        uint rndSeed = CommitRevealInterface(commitrevealLib).getRandom(_cid);
        // TODO: Refine bootstrap algorithm.
        uint arrSize = groupSize * (groupToPick + 1);
        address[] memory candidates = new address[](arrSize);
        for (uint i = 0; i < pendingNodes.length; i++) {
            if (i < arrSize) {
                candidates[i] = pendingNodes[i];
                delete pendingNodeMap[pendingNodes[i]];
            } else {
                pendingNodes[i - arrSize] = pendingNodes[i];
            }
        }
        pendingNodes.length -= arrSize;
        shuffle(candidates, rndSeed);
        regroup(candidates);
        //
    }
    /// End of Guardian functions

    function getGroupPubKey(uint idx) public view returns (uint[4] memory) {
        require(idx < workingGroupIds.length, "group index out of range");

        BN256.G2Point storage pubKey = workingGroups[workingGroupIds[idx]].groupPubKey;
        return [pubKey.x[0], pubKey.x[1], pubKey.y[0], pubKey.y[1]];
    }

    function getWorkingGroupSize() public view returns (uint) {
        return workingGroupIds.length;
    }

    function getPengindNodeSize() public view returns (uint) {
        return pendingNodes.length;
    }

    // TODO: restrict msg.sender from registered and staked node operator.
    function registerNewNode() public {
        require(!pendingNodeMap[msg.sender], "Duplicated pending node");
        require(workingNodeMap[msg.sender].inGroupCount == 0, "Already in working groups");

        pendingNodes.push(msg.sender);
        pendingNodeMap[msg.sender] = true;
        emit LogRegisteredNewPendingNode(msg.sender);
        // Generate new groups from newly registered nodes and nodes from existing working group.
        if (pendingNodes.length < groupSize * groupingThreshold / 100) {
            emit LogInsufficientPendingNode(pendingNodes.length);
        } else if (workingGroupIds.length < groupToPick) {
            // There're enough pending nodes but with non-sufficient working groups.
            emit LogInsufficientWorkingGroup(workingGroupIds.length);
            // TODO: Bootstrap phase.
        } else {
            requestRandom(address(this), 1, block.number);
            emit LogGroupingInitiated(pendingNodes.length, groupSize, groupingThreshold);
        }
    }

    // callback to handle re-grouping using generated random number as random seed.
    function __callback__(uint requestId, uint rndSeed) public {
        require(msg.sender == address(this), "Unauthenticated response");
        require(workingGroupIds.length >= groupToPick,
                "No enough working group");
        require(pendingNodes.length >= groupSize * groupingThreshold / 100,
                "Not enough newly registered nodes");

        uint arrSize = groupSize * (groupToPick + 1);
        address[] memory candidates = new address[](arrSize);
        uint num = 0;
        for (uint i = 1; i <= groupToPick; i++) {
            uint idx = uint(keccak256(abi.encodePacked(rndSeed, requestId, i))) % workingGroupIds.length;
            Group storage grpToDissolve = workingGroups[workingGroupIds[idx]];
            for (uint j = 0; j < groupSize; j++) {
                candidates[num++] = grpToDissolve.members[j];
            }
            //TODO: Because those nodes has been picked here.
            //It should not be added to pendingnNode in dissolveWorkingGroup
            //Other reason that don't dissolve here is that some groups are new groups
            //But it could be chosen to disolve.
            //Maybe it need to check some conditions to decide if this group should be dissolved.
            //dissolveWorkingGroup(idx);
        }

        for (uint i = 0; i < pendingNodes.length; i++) {
            if (i < groupSize) {
                candidates[num++] = pendingNodes[i];
                delete pendingNodeMap[pendingNodes[i]];
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
            // Generated groupId = sha3(...(sha3(sha3(member 1), member 2), ...), member n)
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
    function registerGroupPubKey(uint groupId, uint[4] memory suggestedPubKey) public {
        PendingGroup storage pgrp = pendingGroups[groupId];
        require(pgrp.groupId != 0, "No such pending group to be registered");
        require(pgrp.isMember[msg.sender], "Not from authorized group member");

        bytes32 hashedPubKey = keccak256(abi.encodePacked(
            suggestedPubKey[0], suggestedPubKey[1], suggestedPubKey[2], suggestedPubKey[3]));
        pgrp.pubKeyCounts[hashedPubKey]++;
        emit LogPublicKeySuggested(groupId, suggestedPubKey, pgrp.pubKeyCounts[hashedPubKey], groupSize);
        if (pgrp.pubKeyCounts[hashedPubKey] > groupSize / 2) {
            for (uint i = 0; i < pgrp.members.length; i++) {
                workingNodeMap[pgrp.members[i]].inGroups[groupId] = true;
                workingNodeMap[pgrp.members[i]].inGroupCount++;
            }
            workingGroups[groupId] = Group(
                groupId,
                BN256.G2Point([suggestedPubKey[0], suggestedPubKey[1]], [suggestedPubKey[2], suggestedPubKey[3]]),
                block.number,
                pgrp.members);
            workingGroupIds.push(groupId);

            delete pendingGroups[groupId];
            numPendingGroups--;
            emit LogPublicKeyAccepted(groupId, suggestedPubKey, workingGroupIds.length);
        }
    }
}
