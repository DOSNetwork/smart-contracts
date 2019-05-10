pragma solidity ^0.5.0;
// Do not use in production
// pragma experimental ABIEncoderV2;

import "./lib/BN256.sol";
import "./Ownable.sol";

contract UserContractInterface {
    // Query callback.
    function __callback__(uint, bytes calldata) external;
    // Random number callback.
    function __callback__(uint, uint) external;
}

contract CommitRevealInterface {
    function startCommitReveal(uint, uint, uint, uint) public returns(uint);
    function getRandom(uint) public returns(uint);
}

contract DOSAddressBridgeInterface {
    function getCommitRevealAddress() public view returns(address);
    function getPaymentAddress() public view returns(address);
}

contract DOSPaymentInterface {
    function fromValidStakingNode(address) public view returns(bool);
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
        uint startBlkNum;
        mapping(bytes32 => uint) pubKeyCounts;
        // 0x1 (HEAD) -> member1 -> member2 -> ... -> memberN -> 0x1 (HEAD)
        mapping(address => address) memberList;
    }

    uint requestIdSeed;
    // calling requestId => PendingQuery metadata
    mapping(uint => PendingRequest) PendingRequests;

    uint public refreshSystemRandomHardLimit = 60; // in blocks, ~15min
    uint public groupMaturityPeriod = 11520; // in blocks, ~2days
    // When regrouping, picking @gropToPick working groups, plus one group from pending nodes.
    uint public groupToPick = 2;
    uint public groupSize = 21;
    // decimal 2.
    uint public groupingThreshold = 150;
    // Bootstrapping related arguments, in blocks.
    uint public bootstrapCommitDuration = 3;
    uint public bootstrapRevealDuration = 3;
    uint public bootstrapRevealThreshold = 3;
    uint public bootstrapStartThreshold = groupSize * (groupToPick + 1);
    uint public bootstrapRound = 0;

    // DOSAddressBridge on rinkeby testnet
    DOSAddressBridgeInterface public addressBridge =
        DOSAddressBridgeInterface(0xe987926A226932DFB1f71FA316461db272E05317);

    // Dummy head and placeholder used in linkedlists.
    uint private constant HEAD_I = 0x1;
    address private constant HEAD_A = address(0x1);

    // Linkedlist of newly registered ungrouped nodes, with HEAD points to the earliest and pendingNodeTail points to the latest.
    // Initial state: pendingNodeList[HEAD_A] == HEAD_A && pendingNodeTail == HEAD_A.
    mapping(address => address) public pendingNodeList;
    address public pendingNodeTail;
    uint public numPendingNodes;

    // node => a linkedlist of working groupIds the node is in:
    // node => (0x1 -> workingGroupId1 -> workingGroupId2 -> ... -> workingGroupIdm -> 0x1)
    // Initial state: { nodeAddr : { HEAD_I : HEAD_I } }
    mapping(address => mapping(uint => uint)) public nodeToGroupIdList;

    // groupId => Group
    mapping(uint => Group) workingGroups;
    // Index:groupId
    uint[] public workingGroupIds;

    // groupId => PendingGroup
    mapping(uint => PendingGroup) public pendingGroups;
    uint public pendingGroupMaxLife = 150;  // in blocks

    // Initial state: pendingGroupList[HEAD_I] == HEAD_I && pendingGroupTail == HEAD_I
    mapping(uint => uint) public pendingGroupList;
    uint public pendingGroupTail;
    // TODO: Remove this duplicated state variable to save SSTORE gas.
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
        uint dispatchedGroupId
    );
    event LogRequestUserRandom(
        uint requestId,
        uint lastSystemRandomness,
        uint userSeed,
        uint dispatchedGroupId
    );
    event LogNonSupportedType(string invalidSelector);
    event LogNonContractCall(address from);
    event LogCallbackTriggeredFor(address callbackAddr);
    event LogRequestFromNonExistentUC();
    event LogUpdateRandom(uint lastRandomness, uint dispatchedGroupId);
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
    event LogPublicKeyAccepted(uint groupId, uint[4] pubKey, uint numWorkingGroups);
    event LogPublicKeySuggested(uint count);
    event LogGroupDissolve(uint groupId);
    event LogRegisteredNewPendingNode(address node);
    event LogGroupingInitiated(uint pendingNodePool, uint groupsize, uint groupingthreshold);
    event UpdateGroupToPick(uint oldNum, uint newNum);
    event UpdateGroupSize(uint oldSize, uint newSize);
    event UpdateGroupingThreshold(uint oldThreshold, uint newThreshold);
    event UpdateGroupMaturityPeriod(uint oldPeriod, uint newPeriod);
    event UpdateBootstrapCommitDuration(uint oldDuration, uint newDuration);
    event UpdateBootstrapRevealDuration(uint oldDuration, uint newDuration);
    event UpdateBootstrapRevealThreshold(uint oldThreshold, uint newThreshold);
    event UpdatebootstrapStartThreshold(uint oldThreshold, uint newThreshold);
    event UpdatePendingGroupMaxLife(uint oldLifeBlocks, uint newLifeBlocks);
    event PendingGroupNoExist(uint groupId);
    event GuardianError(string err);
    event GuardianReward(uint blkNum, address indexed guardian);
    // TODO: Remove this debug event.
    event RemovedPendingGroup(uint groupId);

    modifier fromValidStakingNode {
        require(DOSPaymentInterface(addressBridge.getPaymentAddress()).fromValidStakingNode(msg.sender),
                "Invalid staking node");
        _;
    }

    constructor() public {
        pendingNodeList[HEAD_A] = HEAD_A;
        pendingNodeTail = HEAD_A;
        pendingGroupList[HEAD_I] = HEAD_I;
        pendingGroupTail = HEAD_I;
    }

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
        emit UpdateBootstrapCommitDuration(bootstrapCommitDuration, newCommitDuration);
        bootstrapCommitDuration = newCommitDuration;
    }

    function setBootstrapRevealDuration(uint newRevealDuration) public onlyOwner {
        require(newRevealDuration != bootstrapRevealDuration && newRevealDuration != 0);
        emit UpdateBootstrapRevealDuration(bootstrapRevealDuration, newRevealDuration);
        bootstrapRevealDuration = newRevealDuration;
    }

    function setBootstrapRevealThreshold(uint newRevealThreshold) public onlyOwner {
        require(newRevealThreshold != bootstrapRevealThreshold && newRevealThreshold != 0);
        emit UpdateBootstrapRevealThreshold(bootstrapRevealThreshold, newRevealThreshold);
        bootstrapRevealThreshold = newRevealThreshold;
    }

    function setbootstrapStartThreshold(uint newNum) public onlyOwner {
        require(newNum != bootstrapStartThreshold && newNum >= groupSize * (groupToPick + 1));
        emit UpdatebootstrapStartThreshold(bootstrapStartThreshold, newNum);
        bootstrapStartThreshold = newNum;
    }

    function setPendingGroupMaxLife(uint newLife) public onlyOwner {
        require(newLife != pendingGroupMaxLife && newLife != 0);
        emit UpdatePendingGroupMaxLife(pendingGroupMaxLife, newLife);
        pendingGroupMaxLife = newLife;
    }

    function getCodeSize(address addr) private view returns (uint size) {
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
            if (groupMaturityPeriod + group.birthBlkN > block.number) {
                return idx;
            } else {
                dissolveWorkingGroup(idx, true);
            }
        } while(true);
    }

    function dispatchJob(TrafficType trafficType, uint pseudoSeed) private returns(uint) {
        if (block.number - lastUpdatedBlock > refreshSystemRandomHardLimit) {
            kickoffRandom();
        }
        return dispatchJobCore(trafficType, pseudoSeed);
    }

    function kickoffRandom() private {
        lastUpdatedBlock = block.number;
        uint idx = dispatchJobCore(TrafficType.SystemRandom, uint(blockhash(block.number - 1)));
        lastHandledGroup = workingGroups[workingGroupIds[idx]];
        // Signal off-chain clients
        emit LogUpdateRandom(lastRandomness, lastHandledGroup.groupId);
    }

    function insertToPendingGroupListTail(uint groupId) private {
        pendingGroupList[groupId] = pendingGroupList[pendingGroupTail];
        pendingGroupList[pendingGroupTail] = groupId;
        pendingGroupTail = groupId;
        numPendingGroups++;
    }

    function insertToPendingNodeListTail(address node) private {
        pendingNodeList[node] = pendingNodeList[pendingNodeTail];
        pendingNodeList[pendingNodeTail] = node;
        pendingNodeTail = node;
        numPendingNodes++;
    }

    function insertToListHead(mapping(uint => uint) storage list, uint id) private {
        list[id] = list[HEAD_I];
        list[HEAD_I] = id;
    }

    function insertToListHead(mapping(address => address) storage list, address node) private {
        list[node] = list[HEAD_A];
        list[HEAD_A] = node;
    }

    /// Remove id from a storage linkedlist.
    function removeIdFromList(mapping(uint => uint) storage list, uint id) private returns(uint, bool) {
        uint prev = HEAD_I;
        uint curr = list[prev];
        while (curr != HEAD_I && curr != id) {
            prev = curr;
            curr = list[prev];
        }
        if (curr == HEAD_I) {
            return (HEAD_I, false);
        } else {
            list[prev] = list[curr];
            delete list[curr];
            return (prev, true);
        }
    }

    /// @notice Caller ensures no index overflow.
    function dissolveWorkingGroup(uint idx, bool backToPendingPool) private {
        /// Deregister expired working group and remove metadata.
        Group storage grp = workingGroups[workingGroupIds[idx]];
        for (uint i = 0; i < grp.members.length; i++) {
            address member = grp.members[i];
            // Update nodeToGroupIdList[member] and put members back to pendingNodeList's tail if necessary.
            // Notice: Guardian may need to signal group formation.
            uint prev;
            bool removed;
            (prev, removed) = removeIdFromList(nodeToGroupIdList[member], grp.groupId);
            if (removed && prev == HEAD_I && backToPendingPool) {
                insertToPendingNodeListTail(member);
                emit LogRegisteredNewPendingNode(member);
            }
        }
        emit LogGroupDissolve(grp.groupId);

        delete workingGroups[workingGroupIds[idx]];
        workingGroupIds[idx] = workingGroupIds[workingGroupIds.length - 1];
        workingGroupIds.length--;
    }

    // Returns query id.
    // TODO: restrict query from subscribed/paid calling contracts.
    function query(
        address from,
        uint timeout,
        string calldata dataSource,
        string calldata selector
    )
        external
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
                    grp.groupId
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
                grp.groupId
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
        private
        returns (bool)
    {
        // Validation
        // TODO
        // 1. Check msg.sender is a member in Group(grpPubKey).
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
        bytes calldata result,
        uint[2] calldata sig,
        uint8 version
    )
        external
        fromValidStakingNode
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

    function toBytes(uint x) private pure returns (bytes memory b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }

    // System-level secure distributed random number generator.
    function updateRandomness(uint[2] calldata sig, uint8 version) external fromValidStakingNode {
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

        // Some cleanups when updating SystemRandom:
        // 1. Clean up oldest expired PendingGroup and related metadata. Might be due to failed DKG.
        uint gid = pendingGroupList[HEAD_I];
        if (gid != HEAD_I && pendingGroups[gid].startBlkNum + pendingGroupMaxLife < block.number) {
            cleanUpOldestExpiredPendingGroup(gid);
        }
    }

    /// @notice Caller ensures pendingGroupList is not emoty and pending group header has indeed expired.
    function cleanUpOldestExpiredPendingGroup(uint gid) private {
        PendingGroup storage pgrp = pendingGroups[gid];
        address member = pgrp.memberList[HEAD_A];
        uint prev;
        bool removed;
        while (member != HEAD_A) {
            // 1. Update nodeToGroupIdList[member] and 2. put members back to pendingNodeList's head if necessary.
            (prev, removed) = removeIdFromList(nodeToGroupIdList[member], pgrp.groupId);
            if (removed && prev == HEAD_I) {
                insertToListHead(pendingNodeList, member);
            }
            member = pgrp.memberList[member];
        }
        // 3. Update pendingGroupList
        (prev, removed) = removeIdFromList(pendingGroupList, gid);
        require(removed, "Invalid gid in pendingGroupList");
        // Reset pendingGroupTail if necessary.
        if (pendingGroupTail == gid) {
            pendingGroupTail = prev;
        }

        // 4. Update pendingGroup
        delete pendingGroups[gid];
        numPendingGroups--;
        emit RemovedPendingGroup(gid);
    }

    /// Guardian node functions
    // TODO: Tune guardian signal algorithm.
    // TODO: Reward guardian nodes.
    /// @dev Guardian signals expiring system randomness and kicks off distributed random engine again.
    ///  Anyone including but not limited to DOS client node can be a guardian and claim rewards.
    function signalRandom() public {
        if (lastUpdatedBlock + refreshSystemRandomHardLimit > block.number) {
            emit GuardianError("SystemRandom not expired yet");
            return;
        }

        kickoffRandom();
        emit GuardianReward(block.number, msg.sender);
    }
    // TODO: Reward guardian nodes.
    /// @dev Guardian signals to dissolve expired working group and claim for guardian rewards.
    /// @param idx The index in workingGroupIds array.
    function signalDissolve(uint idx) public {
        require(idx < workingGroupIds.length, "Working groups index overflow");
        if (workingGroups[workingGroupIds[idx]].birthBlkN + groupMaturityPeriod > block.number) {
            emit GuardianError("WorkingGroup not expired to be dissolved yet");
            return;
        }

        dissolveWorkingGroup(idx, true);
        emit GuardianReward(block.number, msg.sender);
    }
    // TODO: Reward guardian nodes.
    /// @dev Guardian signals to trigger group formation when there're enough pending nodes.
    ///  If there aren't enough working groups to choose to dossolve, probably a new bootstrap is needed.
    function signalGroupFormation() public {
        if (numPendingNodes < groupSize * groupingThreshold / 10) {
            emit GuardianError("Not enough pending nodes");
            return;
        }

        if (workingGroupIds.length >= groupToPick) {
            requestRandom(address(this), 1, block.number);
            emit LogGroupingInitiated(numPendingNodes, groupSize, groupingThreshold);
        } else if (numPendingNodes >= bootstrapStartThreshold) {
            require(bootstrapRound == 0, "Invalid bootstrap round");
            bootstrapRound = CommitRevealInterface(addressBridge.getCommitRevealAddress()).startCommitReveal(
                block.number,
                bootstrapCommitDuration,
                bootstrapRevealDuration,
                bootstrapRevealThreshold
            );
            emit GuardianReward(block.number, msg.sender);
        }
    }
    // TODO: Reward guardian nodes.
    function signalBootstrap(uint _cid) public {
        require(bootstrapRound == _cid, "Not in bootstrap phase");
        if (numPendingNodes < bootstrapStartThreshold) {
            emit GuardianError("Not enough nodes to bootstrap");
            return;
        }

        // Reset.
        bootstrapRound = 0;

        uint rndSeed = CommitRevealInterface(addressBridge.getCommitRevealAddress()).getRandom(_cid);

        // TODO: Refine bootstrap algorithm to allow group overlapping.
        uint arrSize = bootstrapStartThreshold / groupSize * groupSize;
        address[] memory candidates = new address[](arrSize);

        pick(arrSize, 0, candidates);
        shuffle(candidates, rndSeed);
        regroup(candidates, arrSize / groupSize);
        emit GuardianReward(block.number, msg.sender);
    }
    /// End of Guardian functions

    /// TODO
    function unregisterNode() public {

    }

    // Caller ensures no index overflow.
    function getGroupPubKey(uint idx) public view returns (uint[4] memory) {
        BN256.G2Point storage pubKey = workingGroups[workingGroupIds[idx]].groupPubKey;
        return [pubKey.x[0], pubKey.x[1], pubKey.y[0], pubKey.y[1]];
    }

    function getWorkingGroupSize() public view returns (uint) {
        return workingGroupIds.length;
    }

    function registerNewNode() public fromValidStakingNode {
        require(pendingNodeList[msg.sender] == address(0), "Duplicated pending node");
        require(nodeToGroupIdList[msg.sender][HEAD_I] == 0, "Already registered in pending or working groups");

        nodeToGroupIdList[msg.sender][HEAD_I] = HEAD_I;
        insertToPendingNodeListTail(msg.sender);
        emit LogRegisteredNewPendingNode(msg.sender);

        // Generate new groups from newly registered nodes and nodes from existing working group.
        if (numPendingNodes < groupSize * groupingThreshold / 100) {
            emit LogInsufficientPendingNode(numPendingNodes);
        } else if (workingGroupIds.length < groupToPick) {
            // There're enough pending nodes but with non-sufficient working groups.
            emit LogInsufficientWorkingGroup(workingGroupIds.length);
            // TODO: Bootstrap phase.
        } else {
            requestRandom(address(this), 1, block.number);
            emit LogGroupingInitiated(numPendingNodes, groupSize, groupingThreshold);
        }
    }

    // callback to handle re-grouping using generated random number as random seed.
    function __callback__(uint requestId, uint rndSeed) external {
        require(msg.sender == address(this), "Unauthenticated response");
        require(workingGroupIds.length >= groupToPick,
                "No enough working group");
        require(numPendingNodes >= groupSize * groupingThreshold / 100,
                "Not enough newly registered nodes");

        uint arrSize = groupSize * (groupToPick + 1);
        address[] memory candidates = new address[](arrSize);
        for (uint i = 0; i < groupToPick; i++) {
            uint idx = uint(keccak256(abi.encodePacked(rndSeed, requestId, i))) % workingGroupIds.length;
            Group storage grpToDissolve = workingGroups[workingGroupIds[idx]];
            for (uint j = 0; j < groupSize; j++) {
                candidates[i * groupSize + j] = grpToDissolve.members[j];
            }
            // Do not put chosen to-be-dissolved working group back to pending pool.
            dissolveWorkingGroup(idx, false);
        }

        pick(groupSize, groupSize * groupToPick, candidates);
        shuffle(candidates, rndSeed);
        regroup(candidates, groupToPick + 1);
    }

    // Pick @num nodes from pendingNodeList's head and put into the @candidates array from @startIndex.
    function pick(uint num, uint startIndex, address[] memory candidates) private {
        for (uint i = 0; i < num; i++) {
            address curr = pendingNodeList[HEAD_A];
            pendingNodeList[HEAD_A] = pendingNodeList[curr];
            delete pendingNodeList[curr];
            candidates[startIndex + i] = curr;
        }
        numPendingNodes -= num;
        // Reset pendingNodeTail if necessary.
        if (numPendingNodes == 0) {
            pendingNodeTail = HEAD_A;
        }
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
    function regroup(address[] memory candidates, uint num) private {
        require(candidates.length == groupSize * num);

        address[] memory members = new address[](groupSize);
        uint groupId;
        for (uint i = 0; i < num; i++) {
            groupId = 0;
            // Generated groupId = sha3(...(sha3(sha3(member 1), member 2), ...), member n)
            for (uint j = 0; j < groupSize; j++) {
                members[j] = candidates[i * groupSize + j];
                groupId = uint(keccak256(abi.encodePacked(groupId, members[j])));
            }
            pendingGroups[groupId] = PendingGroup(groupId, block.number);
            mapping(address => address) storage memberList = pendingGroups[groupId].memberList;
            memberList[HEAD_A] = HEAD_A;
            for (uint j = 0; j < groupSize; j++) {
                memberList[members[j]] = memberList[HEAD_A];
                memberList[HEAD_A] = members[j];
            }
            insertToPendingGroupListTail(groupId);
            emit LogGrouping(groupId, members);
        }
    }

    function registerGroupPubKey(uint groupId, uint[4] calldata suggestedPubKey)
        external
        fromValidStakingNode
    {
        PendingGroup storage pgrp = pendingGroups[groupId];
        if (pgrp.groupId == 0) {
            emit PendingGroupNoExist(groupId);
            return;
        }

        require(pgrp.memberList[msg.sender] != address(0), "Not from authorized group member");

        bytes32 hashedPubKey = keccak256(abi.encodePacked(
            suggestedPubKey[0], suggestedPubKey[1], suggestedPubKey[2], suggestedPubKey[3]));
        pgrp.pubKeyCounts[hashedPubKey]++;
        emit LogPublicKeySuggested(pgrp.pubKeyCounts[hashedPubKey]);
        if (pgrp.pubKeyCounts[hashedPubKey] > groupSize / 2) {
            address[] memory memberArray = new address[](groupSize);
            uint idx = 0;
            address member = pgrp.memberList[HEAD_A];
            while (member != HEAD_A) {
                memberArray[idx++] = member;
                // Update nodeToGroupIdList[member] with new group id.
                insertToListHead(nodeToGroupIdList[member], groupId);
                member = pgrp.memberList[member];
            }

            workingGroupIds.push(groupId);
            workingGroups[groupId] = Group(
                groupId,
                BN256.G2Point([suggestedPubKey[0], suggestedPubKey[1]], [suggestedPubKey[2], suggestedPubKey[3]]),
                block.number,
                memberArray
            );

            // Update pendingGroupList
            uint prev;
            bool removed;
            (prev, removed) = removeIdFromList(pendingGroupList, groupId);
            require(removed, "Invalid groupId in pendingGroupList");
            // Reset pendingGroupTail if necessary.
            if (pendingGroupTail == groupId) {
                pendingGroupTail = prev;
            }
            // Update pendingGroup
            delete pendingGroups[groupId];
            numPendingGroups--;
            emit RemovedPendingGroup(groupId);
            emit LogPublicKeyAccepted(groupId, suggestedPubKey, workingGroupIds.length);
        }
    }
}
