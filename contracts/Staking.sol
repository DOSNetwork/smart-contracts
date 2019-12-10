pragma solidity ^0.5.0;

import "./Ownable.sol";

/**
 * @title Staking and delegation contract
 * @author Dos Network
 */

contract ERC20I{
    function balanceOf(address who) public view returns (uint);
    function decimals() public view returns (uint);
    function transfer(address to, uint value) public returns (bool);
    function transferFrom( address from, address to, uint value) public returns (bool);
    function approve(address spender, uint value) public returns (bool);
}

contract DOSAddressBridgeInterface {
    function getProxyAddress() public view returns(address);
}

contract Staking is Ownable {
    uint public constant ONEYEAR = 365 days;
    uint public initBlkN;
    // Testnet token contract addresses
    address public  DOSTOKEN;
    address public  DBTOKEN ;
    address public  stakingRewardsVault;
    uint public constant DOSDECIMAL = 18;
    uint public constant DBDECIMAL = 0;
    uint private constant LISTHEAD = 0x1;

    uint public minStakePerNode = 100000 * (10 ** DOSDECIMAL);
    //uint public maxStakePerNode = 500000 * (10 ** DOSDECIMAL);
    uint public dropburnMaxQuota = 3;
    uint public totalStakedTokens;
    uint public inverseStakeRatio;
    uint public circulatingSupply = 131950000 * (10 ** DOSDECIMAL);
    uint public unbondDuration = 7 days;

    uint public lastRateUpdatedTime;  // in seconds
    uint public accumulatedRewardRate;  // A float point multiplied by 1e10

    // DOSAddressBridge
    DOSAddressBridgeInterface public addressBridge;
    address public bridgeAddr;

    struct Node {
        address ownerAddr;
        uint rewardCut;  // %, [0, 100).
        uint stakedDB;   // [0, dropburnMaxQuota]
        uint selfStakedAmount;
        uint totalOtherDelegatedAmount;
        uint accumulatedReward;
        uint accumulatedRewardRate;
        uint pendingWithdrawToken;
        uint pendingWithdrawDB;
        uint lastStartTime;
        uint lastStopTime;
        bool running;
        string description;
        //
        address[] nodeDelegators;
        // release time => UnbondRequest metadata
        mapping (uint => UnbondRequest) unbondRequests;
        // LISTHEAD => release time 1 => ... => release time m => LISTHEAD
        mapping (uint => uint) releaseTime;
    }

    struct UnbondRequest {
        uint dosAmount;
        uint dbAmount;
    }

    struct Delegation {
        address delegatedNode;
        uint delegatedAmount;
        uint accumulatedReward; // in tokens
        uint accumulatedRewardRate;
        uint pendingWithdraw;

        // release time => UnbondRequest metadata
        mapping (uint => UnbondRequest) unbondRequests;
        // LISTHEAD => release time 1 => ... => release time m => LISTHEAD
        mapping (uint => uint) releaseTime;
    }

    // 1:1 node address => Node metadata
    mapping (address => Node) public nodes;
    address[] public nodeAddrs;

    // node runner's main address => {node addresses}
    mapping (address => mapping(address => bool)) public nodeRunners;
    // 1:n token holder address => {delegated node 1 : Delegation, ..., delegated node n : Delegation}
    mapping (address => mapping(address => Delegation)) public delegators;

    event UpdateDropBurnMaxQuota(uint oldQuota, uint newQuota);
    event UpdateUnbondDuration(uint oldDuration, uint newDuration);
    event UpdateCirculatingSupply(uint oldCirculatingSupply, uint newCirculatingSupply);
    event UpdateMinStakePerNode(uint oldMinStakePerNode, uint newMinStakePerNode);
    //event UpdateMaxStakePerNode(uint oldMaxStakePerNode, uint newMaxStakePerNode);
    event LogNewNode(address indexed owner, address nodeAddress, uint selfStakedAmount, uint stakedDB, uint rewardCut);
    event DelegateTo(address indexed sender,uint total, address nodeAddr);
    event RewardWithdraw(address indexed sender,uint total);
    event Unbond(address indexed sender,uint tokenAmount, uint dropburnAmount, address nodeAddr);

    constructor(address _dostoken,address _dbtoken,address _vault,address _bridgeAddr) public {
        initBlkN = block.number;
        DOSTOKEN = _dostoken;
        DBTOKEN = _dbtoken;
        stakingRewardsVault = _vault;
        bridgeAddr = _bridgeAddr;
        addressBridge = DOSAddressBridgeInterface(bridgeAddr);
    }

    /// @dev used when drop burn max quota duration is changed
    function setDropBurnMaxQuota(uint _quota) public onlyOwner {
        require(_quota != dropburnMaxQuota && _quota < 10, "Valid dropburnMaxQuota within 0 to 9");
        emit UpdateDropBurnMaxQuota(dropburnMaxQuota, _quota);
        dropburnMaxQuota = _quota;
    }

    /// @dev used when withdraw duration is changed
    function setUnbondDuration(uint _duration) public onlyOwner {
        emit UpdateUnbondDuration(unbondDuration, _duration);
        unbondDuration = _duration;
    }

    /// @dev used when locked token is unlocked
    // TODO: update global accumulatedRewardRate accordingly
    function setCirculatingSupply(uint _newSupply) public onlyOwner {
        require(circulatingSupply >= totalStakedTokens,"CirculatingSupply is less than totalStakedTokens");
        emit UpdateCirculatingSupply(circulatingSupply, _newSupply);
        circulatingSupply = _newSupply;
    }

    /// @dev used when minStakePerNode is updated
    function setMinStakePerNode(uint _minStake)  public onlyOwner {
        emit UpdateMinStakePerNode(minStakePerNode, _minStake);
        minStakePerNode = _minStake;
    }

    /// @dev used when maxStakePerNode is updated
    //function setMaxStakePerNode(uint _maxStake) public onlyOwner {
    //    emit UpdateMaxStakePerNode(maxStakePerNode, _maxStake);
    //    maxStakePerNode = _maxStake;
    //}
    function getNodeAddrs() public view returns(address[]memory){
        return nodeAddrs;
    }
    function min(uint a, uint b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    modifier checkStakingValidity(uint _tokenAmount, uint _dropburnAmount, uint _rewardCut) {
        require(0 <= _rewardCut && _rewardCut < 100, "Not valid reward cut percentage");
        require(_tokenAmount>=minStakePerNode * (10 - min(_dropburnAmount / (10 ** DBDECIMAL), dropburnMaxQuota)) / 10,
                "Not enough dos token to start a node");
        //require(_tokenAmount<=maxStakePerNode, "Reach maximum number of dos tokens per node");
        _;
    }

    modifier onlyFromProxy() {
        require(msg.sender==addressBridge.getProxyAddress(), "Not from proxy contract");
        _;
    }

    function isValidStakingNode(address nodeAddr) public view returns(bool) {
        Node storage node = nodes[nodeAddr];
        uint _tokenAmount = node.selfStakedAmount;
        uint _dropburnAmount = node.stakedDB;
        if (_tokenAmount>=minStakePerNode * (10 - min(_dropburnAmount / (10 ** DBDECIMAL), dropburnMaxQuota)) / 10) {
            return true;
        }
        return false;
    }

    function newNode(address _nodeAddr, uint _tokenAmount, uint _dropburnAmount, uint _rewardCut,string memory _desc)
        public checkStakingValidity(_tokenAmount, _dropburnAmount, _rewardCut) {
        require(!nodeRunners[msg.sender][_nodeAddr], "Node is already registered");
        require(nodes[_nodeAddr].ownerAddr == address(0),"Node is already registered");

        nodeRunners[msg.sender][_nodeAddr] = true;
        // Deposit tokens.
        ERC20I(DOSTOKEN).transferFrom(msg.sender, address(this), _tokenAmount);
        if (_dropburnAmount > 0) {
            ERC20I(DBTOKEN).transferFrom(msg.sender, address(this), _dropburnAmount);
        }

        address[] memory nodeDelegators;
        nodes[_nodeAddr] = Node(msg.sender, _rewardCut, _dropburnAmount, _tokenAmount, 0, 0, 0, 0, 0, 0, 0, false,
        _desc,nodeDelegators);
        nodes[_nodeAddr].releaseTime[LISTHEAD] = LISTHEAD;
        nodeAddrs.push(_nodeAddr);
        emit LogNewNode(msg.sender, _nodeAddr, _tokenAmount, _dropburnAmount, _rewardCut);
    }

    function nodeStart(address _nodeAddr) public onlyFromProxy {
        require(nodes[_nodeAddr].ownerAddr != address(0),"Node is not registered");
        Node storage node = nodes[_nodeAddr];
        if (!node.running) {
            node.running = true;
            node.lastStartTime = now;
            updateGlobalRewardRate();
            node.accumulatedRewardRate = accumulatedRewardRate;
            for (uint i = 0; i < node.nodeDelegators.length; i++) {
                Delegation storage delegator = delegators[node.nodeDelegators[i]][_nodeAddr];
                delegator.accumulatedRewardRate = accumulatedRewardRate;
            }
            // This would change interest rate
            totalStakedTokens += node.selfStakedAmount + node.totalOtherDelegatedAmount;
        }
    }

    function nodeStop(address _nodeAddr) public onlyFromProxy {
        require(nodes[_nodeAddr].ownerAddr != address(0),"Node is not registered");
        nodeStopInternal(_nodeAddr);
    }

    function nodeStopInternal(address _nodeAddr) internal {
        Node storage node = nodes[_nodeAddr];
        if (node.running) {
            updateGlobalRewardRate();
            node.accumulatedReward = getNodeRewardTokens(_nodeAddr);
            node.accumulatedRewardRate = accumulatedRewardRate;
            for (uint i = 0; i < node.nodeDelegators.length; i++) {
                Delegation storage delegator = delegators[node.nodeDelegators[i]][_nodeAddr];
                delegator.accumulatedReward = getDelegatorRewardTokens(node.nodeDelegators[i], _nodeAddr);
                delegator.accumulatedRewardRate = accumulatedRewardRate;
            }
            node.running = false;
            // This would change interest rate
	        totalStakedTokens -= node.selfStakedAmount - node.totalOtherDelegatedAmount;
            node.lastStopTime = now;
        }
    }

    // For node runners to configure new staking settings.
    function updateNodeStaking(address _nodeAddr, uint _newTokenAmount, uint _newDropburnAmount, uint _newCut) public {
        require(nodeRunners[msg.sender][_nodeAddr], "Node is not owned by msg.sender");

        Node storage node = nodes[_nodeAddr];
        if (node.running==true) {
            // Update global accumulated interest rate.
            updateGlobalRewardRate();
            node.accumulatedReward = getNodeRewardTokens(_nodeAddr);
        }
        node.accumulatedRewardRate = accumulatedRewardRate;
        // _newCut with value uint(-1) means skipping this config.
        if (_newCut != uint(-1)) {
            require(_newCut >= 0 && _newCut < 100, "Not valid reward cut percentage");
            // TODO: Update rewardCut affects delegators' reward calculation.
            node.rewardCut = _newCut;
        }
        if (_newDropburnAmount != 0) {
            node.stakedDB += _newDropburnAmount;
            ERC20I(DBTOKEN).transferFrom(msg.sender, address(this), _newDropburnAmount);
        }
        if (_newTokenAmount != 0) {
            //require(node.selfStakedAmount + node.totalOtherDelegatedAmount + _newTokenAmount <= maxStakePerNode,
            //        "Reach maximum number of dos tokens per node");
            node.selfStakedAmount += _newTokenAmount;
            if (node.running==true) {
                // This would change interest rate
                totalStakedTokens += _newTokenAmount;
            }
            ERC20I(DOSTOKEN).transferFrom(msg.sender, address(this), _newTokenAmount);
        }
    }

    // Token holders (delegators) call this function. It's allowed to delegate to the same node multiple times if possible.
    // Note: Re-delegate is not supported.
    function delegate(uint _tokenAmount, address _nodeAddr) public {
        Node storage node = nodes[_nodeAddr];
        require(node.ownerAddr != address(0), "Node doesn't exist");
        require(msg.sender != node.ownerAddr, "Node owner cannot self-delegate");
        //require(node.selfStakedAmount + node.totalOtherDelegatedAmount + _tokenAmount <= maxStakePerNode,
        //        "Reach maximum number of dos tokens per node");

        Delegation storage delegator = delegators[msg.sender][_nodeAddr];
        require(delegator.delegatedNode == address(0) || delegator.delegatedNode == _nodeAddr, "Invalid delegated node address");
        if (node.running==true) {
            // Update global accumulated interest rate.
            updateGlobalRewardRate();
            delegator.accumulatedReward = getDelegatorRewardTokens(msg.sender, _nodeAddr);
        }
        delegator.accumulatedRewardRate = accumulatedRewardRate;
        delegator.delegatedAmount += _tokenAmount;
        if (delegator.delegatedNode == address(0)) {
            // New delegation
            delegator.delegatedNode = _nodeAddr;
            delegator.releaseTime[LISTHEAD] = LISTHEAD;
        }
        if (node.running==true) {
            node.accumulatedReward = getNodeRewardTokens(_nodeAddr);
            totalStakedTokens += _tokenAmount;
        }
        node.nodeDelegators.push(msg.sender);
        node.totalOtherDelegatedAmount += _tokenAmount;
        node.accumulatedRewardRate = accumulatedRewardRate;
        emit DelegateTo(msg.sender,_tokenAmount, _nodeAddr);

        ERC20I(DOSTOKEN).transferFrom(msg.sender, address(this), _tokenAmount);
    }

    function nodeUnregister(address _nodeAddr) public {
        require(nodeRunners[msg.sender][_nodeAddr], "Node is not owned by msg.sender");
        Node storage node = nodes[_nodeAddr];
        nodeUnbondInternal(node.selfStakedAmount,node.stakedDB,_nodeAddr);
    }

    function nodeTryDelete(address _nodeAddr) public {
        if (nodes[_nodeAddr].selfStakedAmount == 0 && nodes[_nodeAddr].stakedDB == 0 &&
            nodes[_nodeAddr].totalOtherDelegatedAmount == 0 && nodes[_nodeAddr].accumulatedReward == 0 &&
            nodes[_nodeAddr].nodeDelegators.length==0) {
                delete nodeRunners[nodes[_nodeAddr].ownerAddr][_nodeAddr];
                delete nodes[_nodeAddr];
                for (uint idx = 0; idx < nodeAddrs.length; idx++) {
                    if (nodeAddrs[idx] == _nodeAddr) {
                        nodeAddrs[idx] = nodeAddrs[nodeAddrs.length - 1];
                        nodeAddrs.length--;
                        return;
                    }
                }
        }
    }
    // Used by node runners to unbond their stakes.
    // Unbonded tokens are locked for 7 days, during the unbonding period they're not eligible for staking rewards.
    function nodeUnbond(uint _tokenAmount, uint _dropburnAmount, address _nodeAddr) public {
        require(nodeRunners[msg.sender][_nodeAddr], "Node is not owned by msg.sender");
        Node storage node = nodes[_nodeAddr];

        require(_tokenAmount <= node.selfStakedAmount, "Invalid request to unbond more than staked token");
        require(_dropburnAmount <= node.stakedDB, "Invalid request to unbond more than staked DropBurn token");
        require(node.selfStakedAmount - _tokenAmount >=
                minStakePerNode * (10 - min(node.stakedDB - _dropburnAmount / (10 ** DBDECIMAL), dropburnMaxQuota)) / 10,
                "Invalid unbond request to maintain node staking requirement");
        nodeUnbondInternal(_tokenAmount,_dropburnAmount,_nodeAddr);
    }
    // Used by node runners to unbond their stakes.
    // Unbonded tokens are locked for 7 days, during the unbonding period they're not eligible for staking rewards.
    function nodeUnbondInternal(uint _tokenAmount, uint _dropburnAmount, address _nodeAddr) internal {
        require(nodeRunners[msg.sender][_nodeAddr], "Node is not owned by msg.sender");
        Node storage node = nodes[_nodeAddr];
        if (node.running==true) {
            updateGlobalRewardRate();
            node.accumulatedReward = getNodeRewardTokens(_nodeAddr);
            // This would change interest rate
            totalStakedTokens -= _tokenAmount;
        }
        node.accumulatedRewardRate = accumulatedRewardRate;
        node.selfStakedAmount -= _tokenAmount;
        node.pendingWithdrawToken += _tokenAmount;
        node.stakedDB -= _dropburnAmount;
        node.pendingWithdrawDB += _dropburnAmount;

        if (_tokenAmount > 0 || _dropburnAmount > 0) {
            // create an UnbondRequest
            uint releaseTime = now + unbondDuration;
            node.unbondRequests[releaseTime] = UnbondRequest(_tokenAmount, _dropburnAmount);
            node.releaseTime[releaseTime] = node.releaseTime[LISTHEAD];
            node.releaseTime[LISTHEAD] = releaseTime;
        }

        if (node.selfStakedAmount - _tokenAmount >=
            minStakePerNode * (10 - min(node.stakedDB - _dropburnAmount / (10 ** DBDECIMAL), dropburnMaxQuota)) / 10){
            nodeStopInternal(_nodeAddr);
         }
         emit Unbond(msg.sender,_tokenAmount, _dropburnAmount, _nodeAddr);
    }

    // Used by token holders (delegators) to unbond their delegations.
    function delegatorUnbond(uint _tokenAmount, address _nodeAddr) public {
        Delegation storage delegator = delegators[msg.sender][_nodeAddr];
        require(nodes[_nodeAddr].ownerAddr != address(0), "Node doesn't exist");
        require(delegator.delegatedNode == _nodeAddr, "Cannot unbond from non-delegated node");
        require(_tokenAmount <= delegator.delegatedAmount, "Cannot unbond more than delegated token");
        if (nodes[_nodeAddr].running==true) {
            updateGlobalRewardRate();
            delegator.accumulatedReward = getDelegatorRewardTokens(msg.sender, _nodeAddr);
            // This would change interest rate
            totalStakedTokens -= _tokenAmount;
            nodes[_nodeAddr].accumulatedReward = getNodeRewardTokens(_nodeAddr);
        }
        delegator.accumulatedRewardRate = accumulatedRewardRate;
        delegator.delegatedAmount -= _tokenAmount;
        delegator.pendingWithdraw += _tokenAmount;
        nodes[_nodeAddr].accumulatedRewardRate = accumulatedRewardRate;
        nodes[_nodeAddr].totalOtherDelegatedAmount -= _tokenAmount;

        if (_tokenAmount > 0) {
            // create a UnbondRequest
            uint releaseTime = now + unbondDuration;
            delegator.unbondRequests[releaseTime] = UnbondRequest(_tokenAmount, 0);
            delegator.releaseTime[releaseTime] = delegator.releaseTime[LISTHEAD];
            delegator.releaseTime[LISTHEAD] = releaseTime;
        }
    }

    function withdrawAll(mapping(uint => uint) storage releaseTimeList, mapping(uint => UnbondRequest) storage requestList)
        internal
        returns(uint, uint)
    {
        uint accumulatedDos = 0;
        uint accumulatedDropburn = 0;
        uint prev = LISTHEAD;
        uint curr = releaseTimeList[prev];
        while (curr != LISTHEAD && curr > now) {
            prev = curr;
            curr = releaseTimeList[prev];
        }
        if (releaseTimeList[prev] != LISTHEAD) {
            releaseTimeList[prev] = LISTHEAD;
        }
        // All next items are withdrawable.
        while (curr != LISTHEAD) {
            accumulatedDos += requestList[curr].dosAmount;
            accumulatedDropburn += requestList[curr].dbAmount;
            prev = curr;
            curr = releaseTimeList[prev];
            delete releaseTimeList[prev];
            delete requestList[prev];
        }
        return (accumulatedDos, accumulatedDropburn);
    }

    // Node runners call this function to withdraw available unbonded tokens after unbond period.
    function nodeWithdraw(address _nodeAddr) public {
        Node storage node = nodes[_nodeAddr];
        require(node.ownerAddr == msg.sender, "msg.sender is not authorized to withdraw from node");

        (uint tokenAmount, uint dropburnAmount) = withdrawAll(node.releaseTime, node.unbondRequests);
        node.pendingWithdrawToken -= tokenAmount;
        node.pendingWithdrawDB -= dropburnAmount;

        nodeTryDelete(_nodeAddr);
        if (tokenAmount > 0) {
            ERC20I(DOSTOKEN).transfer(msg.sender, tokenAmount);
        }
        if (dropburnAmount > 0) {
            ERC20I(DBTOKEN).transfer(msg.sender, dropburnAmount);
        }
    }
    // Delegators call this function to withdraw available unbonded tokens from a specific node after unbond period.
    function delegatorWithdraw(address _nodeAddr) public {
        Delegation storage delegator = delegators[msg.sender][_nodeAddr];
        require(nodes[_nodeAddr].ownerAddr != address(0), "Node doesn't exist");
        require(delegator.delegatedNode == _nodeAddr, "Cannot withdraw from non-delegated node");

        (uint tokenAmount, ) = withdrawAll(delegator.releaseTime, delegator.unbondRequests);
        if (tokenAmount > 0) {
            delegator.pendingWithdraw -= tokenAmount;
            if (delegator.delegatedAmount == 0 && delegator.pendingWithdraw == 0 && delegator.accumulatedReward == 0) {
                delete delegators[msg.sender][_nodeAddr];
                uint idx = 0;
                for (; idx < nodes[_nodeAddr].nodeDelegators.length; idx++) {
                    if (nodes[_nodeAddr].nodeDelegators[idx] == msg.sender) {
                        break;
                    }
                }
                if (idx < nodes[_nodeAddr].nodeDelegators.length) {
                    nodes[_nodeAddr].nodeDelegators[idx] = nodes[_nodeAddr].nodeDelegators[nodes[_nodeAddr].nodeDelegators.length - 1];
                    nodes[_nodeAddr].nodeDelegators.length--;
                }
            }
            emit RewardWithdraw(msg.sender, tokenAmount);
            ERC20I(DOSTOKEN).transfer(msg.sender, tokenAmount);
        }
        nodeTryDelete(_nodeAddr);
    }

    function nodeClaimReward(address _nodeAddr) public {
        Node storage node = nodes[_nodeAddr];
        require(node.ownerAddr == msg.sender, "msg.sender is not authorized to claim from node");
        updateGlobalRewardRate();
        uint claimedReward = getNodeRewardTokens(_nodeAddr);
        node.accumulatedReward = 0;
        node.accumulatedRewardRate = accumulatedRewardRate;
        // This would change interest rate
        circulatingSupply += claimedReward;
        ERC20I(DOSTOKEN).transferFrom(stakingRewardsVault, msg.sender, claimedReward);
    }

    function delegatorChekcReward(address _nodeAddr) public returns(uint) {
        Delegation storage delegator = delegators[msg.sender][_nodeAddr];
        require(nodes[_nodeAddr].ownerAddr != address(0), "Node doesn't exist");
        require(delegator.delegatedNode == _nodeAddr, "Cannot claim from non-delegated node");
        updateGlobalRewardRate();
        delegator.accumulatedReward = getDelegatorRewardTokens(msg.sender, _nodeAddr);
        delegator.accumulatedRewardRate = accumulatedRewardRate;
        return delegator.accumulatedReward;
    }

    function delegatorClaimReward(address _nodeAddr) public {
        Delegation storage delegator = delegators[msg.sender][_nodeAddr];
        require(nodes[_nodeAddr].ownerAddr != address(0), "Node doesn't exist");
        require(delegator.delegatedNode == _nodeAddr, "Cannot claim from non-delegated node");
        updateGlobalRewardRate();
        uint claimedReward = getDelegatorRewardTokens(msg.sender, _nodeAddr);

        if (delegator.delegatedAmount == 0 && delegator.pendingWithdraw == 0) {
            delete delegators[msg.sender][_nodeAddr];
        } else {
            delegator.accumulatedReward = 0;
            delegator.accumulatedRewardRate = accumulatedRewardRate;
        }
        // This would change interest rate
        circulatingSupply += claimedReward;
        ERC20I(DOSTOKEN).transferFrom(stakingRewardsVault, msg.sender, claimedReward);
    }

    function getNodeUptime(address nodeAddr) public view returns(uint) {
        Node storage node = nodes[nodeAddr];
        if (node.running){
            return now - node.lastStartTime;
        }else{
            return node.lastStopTime - node.lastStartTime;
        }
    }

    // return a percentage in [4.00, 80.00] (400, 8000)
    function getCurrentAPR() public view returns (uint) {
        if (totalStakedTokens == 0) {
            return 8000;
        }
        uint localinverseStakeRatio = circulatingSupply * 1e4 / totalStakedTokens;
        if (localinverseStakeRatio > 20 * 1e4) {
            // staking rate <= 5%, APR 80%
            return 8000;
        } else {
            return localinverseStakeRatio / 25;
        }
    }

    function rewardRateDelta() public view returns (uint) {
        return (now - lastRateUpdatedTime) * getCurrentAPR() * 1e6 / ONEYEAR;
    }

    function updateGlobalRewardRate() public {
        accumulatedRewardRate += rewardRateDelta();
        lastRateUpdatedTime = now;
    }

    function getNodeRewardTokens(address nodeAddr) public view returns(uint) {
        Node storage node = nodes[nodeAddr];
        if (node.running){
            return node.accumulatedReward +
                (node.selfStakedAmount + node.totalOtherDelegatedAmount * node.rewardCut / 100)  *
                (accumulatedRewardRate - node.accumulatedRewardRate) / 1e10;
        }else {
            return node.accumulatedReward;
        }
    }

    function getDelegatorRewardTokens(address _delegator, address _nodeAddr) public view returns(uint) {
        Node storage node = nodes[_nodeAddr];
        Delegation storage delegator = delegators[_delegator][_nodeAddr];
        if (node.running){
            return delegator.accumulatedReward +
                (delegator.delegatedAmount * (100 - node.rewardCut) / 100) *
                (accumulatedRewardRate - delegator.accumulatedRewardRate) / 1e10;
        }else{
            return delegator.accumulatedReward;
        }
    }


    function nodeWithdrawAble(address _owner,address _nodeAddr) public view returns(uint,uint) {
        Node storage node = nodes[_nodeAddr];
        if (node.ownerAddr != _owner){
            return (0,0);
        }
        return withdrawAbleAmount(node.releaseTime, node.unbondRequests);
    }

    function delegatorWithdrawAble(address _owner,address _nodeAddr) public view returns(uint) {
        Delegation storage delegator = delegators[_owner][_nodeAddr];
        uint tokenAmount = 0;
        (tokenAmount, ) = withdrawAbleAmount(delegator.releaseTime, delegator.unbondRequests);
        return tokenAmount;
    }

    function withdrawAbleAmount(mapping(uint => uint) storage releaseTimeList, mapping(uint => UnbondRequest) storage requestList)
        internal
        view
        returns(uint, uint)
    {
        uint accumulatedDos = 0;
        uint accumulatedDropburn = 0;
        uint prev = LISTHEAD;
        uint curr = releaseTimeList[prev];
        while (curr != LISTHEAD && curr > now) {
            prev = curr;
            curr = releaseTimeList[prev];
        }
        // All next items are withdrawable.
        while (curr != LISTHEAD) {
            accumulatedDos += requestList[curr].dosAmount;
            accumulatedDropburn += requestList[curr].dbAmount;
            prev = curr;
            curr = releaseTimeList[prev];

        }
        return (accumulatedDos, accumulatedDropburn);
    }
}
