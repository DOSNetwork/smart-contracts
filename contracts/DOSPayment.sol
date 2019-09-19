pragma solidity ^0.5.0;

import "./Ownable.sol";

contract ERC20I {
    function balanceOf(address who) public view returns (uint);
    function decimals() public view returns (uint);
    // function allowance(address owner, address spender) public view returns (uint);
    function transfer(address to, uint value) public returns (bool);
    function transferFrom(address from, address to, uint value) public returns (bool);
    // function approve(address spender, uint value) public returns (bool);
}

contract DOSAddressBridgeInterface {
    function getProxyAddress() public view returns (address);
}

contract DOSPayment is Ownable {

    struct FeeList {
        uint serviceFee;
        uint submitterRate;
        uint workerRate;
        uint denominator;
        uint guardianFee;
    }

    struct ServiceFee {
        address requester;
        address tokenAddr;
        uint fee;
    }

    struct Tokens {
        //tokenAddr to amount
        mapping(address => uint) amount;
        address[] tokenAddres;
    }

    //TokenAddr => feeList
    mapping(address => FeeList) _feeList;
    // requestID => Fee metadata
    mapping(uint => ServiceFee) _serviceFees;
    // node address => Reward
    mapping(address => Tokens) _nodeRewards;

    // DOS Token on rinkeby testnet
    address public _defaultTokenAddr = 0xe90EF85fff4f38e742769Ad45DB7eCd3FC935973;
    uint public _defaultDenominator = 5;
    uint public _defaultSubmitterRate = 3;
    uint public _defaultWorkerRate = 2;
    uint public _defaultGuardianFee = 1000000000000000000; // 1 Tokens
    uint public _defaultServiceFee = 5000000000000000000; // 1 Tokens

    // DOS Address Bridge on rinkeby testnet
    DOSAddressBridgeInterface dosAddrBridge =
        DOSAddressBridgeInterface(0x629369c8615f70B789d929198dAD33665139564B);

    // DOS Token on rinkeby testnet
    address public networkToken = 0x214e79c85744CD2eBBc64dDc0047131496871bEe;
    // DropBurn Token on rinkeby testnet
    address public dropburnToken = 0x9bfE8F5749d90eB4049Ad94CC4De9b6C4C31f822;
    uint public minStake = 50000;  // Minimum number of tokens required to be eligible into the protocol network.
    uint public dropburnMaxQuota = 3;  // Each DropBurn quota reduces 10% of minStake requirement to participate into protocol.

    event UpdateNetworkTokenAddress(address oldAddress, address newAddress);
    event UpdateDropBurnTokenAddress(address oldAddress, address newAddress);
    event UpdateDropBurnMaxQuota(uint oldQuota, uint newQuota);
    event LogChargeServiceFee(address,uint,address,uint);
    event LogRefundServiceFee(address,uint,address,uint);
    event LogClaimServiceFee(uint ,address ,address,uint);

    modifier onlyProxy {
        require(msg.sender == dosAddrBridge.getProxyAddress(), "Not from DOS proxy!");
        _;
    }

    modifier onlySupportedToken(address tokenAddr) {
        require(isSupportedToken(tokenAddr), "Not a supported token address!");
        _;
    }

    constructor() public {
        FeeList storage feeList = _feeList[_defaultTokenAddr];
        feeList.serviceFee = _defaultServiceFee;
        feeList.submitterRate = _defaultSubmitterRate;
        feeList.workerRate = _defaultWorkerRate;
        feeList.denominator = _defaultDenominator;
        feeList.guardianFee = _defaultGuardianFee;
    }

    function isSupportedToken(address tokenAddr) public view returns(bool){
       if (tokenAddr == address(0x0) || _feeList[tokenAddr].serviceFee == 0) {
           return false;
       }
       return true;
    }

    function setFees(address tokenAddr,uint serviceFee,uint submitterRate,uint workerRate,uint guardianRate,uint denominator) public onlyOwner{
        require(tokenAddr!=address(0x0), "Not a valid address!");
        FeeList storage feeList = _feeList[tokenAddr];
        feeList.serviceFee = serviceFee;
        feeList.submitterRate = submitterRate;
        feeList.workerRate = workerRate;
        feeList.denominator = denominator;
        feeList.guardianFee = guardianRate;
    }

    function depositGuardianRewards(address tokenAddr,uint amount) public onlyOwner onlySupportedToken(tokenAddr) {
        transferTokenTo(_nodeRewards[address(this)],tokenAddr,amount);
        ERC20I(tokenAddr).transferFrom(msg.sender, address(this),amount);
    }

    function chargeServiceFee(address tokenAddr,uint requestID,address requester) public onlyProxy onlySupportedToken(tokenAddr) {
        uint fee = _feeList[tokenAddr].serviceFee;
        uint balance = ERC20I(tokenAddr).balanceOf(requester);
        if (balance < fee) {
            revert("No enough balance.");
        }

        ServiceFee storage serviceFee = _serviceFees[requestID];
        serviceFee.requester = requester;
        serviceFee.tokenAddr = tokenAddr;
        serviceFee.fee = fee;

        emit LogChargeServiceFee(requester,requestID,tokenAddr,fee);
        ERC20I(tokenAddr).transferFrom(requester, address(this),fee);
    }

    function refundServiceFee(uint requestID) public onlyOwner {
        require(_serviceFees[requestID].fee!=0, "No fee infomation!");
        uint fee = _serviceFees[requestID].fee;
        address tokenAddr = _serviceFees[requestID].tokenAddr;
        address requester = _serviceFees[requestID].requester;
        delete _serviceFees[requestID];
        emit LogRefundServiceFee(requester,requestID,tokenAddr,fee);
        ERC20I(tokenAddr).transfer(requester,fee);
    }

    function claimServiceFee(uint requestID,address submitter,address[] memory workers) public onlyProxy {
        require(_serviceFees[requestID].fee != 0, "No fee infomation!");
        require(workers.length >= 3, "Not a valid workers length!");
        address tokenAddr = _serviceFees[requestID].tokenAddr;
        uint fee = _serviceFees[requestID].fee;
        delete _serviceFees[requestID];

        // TODO : Adjust dividends strategy
        FeeList memory feeList = _feeList[tokenAddr];
        fee = fee/feeList.denominator;
        uint feeForSubmitter = fee * feeList.workerRate;
        uint feeForWorker = (fee * feeList.workerRate)/(workers.length-1);

        transferTokenTo(_nodeRewards[submitter],tokenAddr,feeForSubmitter);
        emit LogClaimServiceFee(requestID,submitter,tokenAddr,feeForSubmitter);
        for (uint i = 0; i < workers.length; i++) {
            if (workers[i] != submitter){
                transferTokenTo(_nodeRewards[workers[i]],tokenAddr,feeForWorker);
                emit LogClaimServiceFee(requestID,workers[i],tokenAddr,feeForWorker);
            }
        }
    }

    function claimGuardianReward(address guardianAddr,address tokenAddr) public onlyProxy {
        require(_nodeRewards[address(this)].tokenAddres.length!=0, "No rewards!");
        require(_nodeRewards[address(this)].amount[tokenAddr]>=_feeList[tokenAddr].guardianFee, "No enough funds for guardian!");
        Tokens storage funds = _nodeRewards[address(this)];
        Tokens storage guardian = _nodeRewards[guardianAddr];
        transferTokenFrom(funds,guardian,tokenAddr,_feeList[tokenAddr].guardianFee);
    }

    function transferTokenTo(Tokens storage tokens,address tokenAddr,uint amount) internal{
        uint tokenAmount = tokens.amount[tokenAddr];
        if (tokenAmount == 0) {
            tokens.tokenAddres.push(tokenAddr);
        }
        tokens.amount[tokenAddr] = tokenAmount + amount;
    }

    function transferTokenFrom(Tokens storage src,Tokens storage dist,address tokenAddr,uint amount) internal{
        require(src.amount[tokenAddr] >= amount, "No enough amount!");
        src.amount[tokenAddr] = src.amount[tokenAddr] - amount;
        if (src.amount[tokenAddr] == 0) {
            src.tokenAddres.pop();
        }
        if (dist.amount[tokenAddr] == 0) {
            dist.tokenAddres.push(tokenAddr);
        }
        dist.amount[tokenAddr] = dist.amount[tokenAddr] + amount;
    }

    function withdraw() public {
        require(_nodeRewards[msg.sender].tokenAddres.length!=0, "No rewards!");
        Tokens storage rewards = _nodeRewards[msg.sender];
        address tokenAddr = rewards.tokenAddres[rewards.tokenAddres.length-1];
        rewards.tokenAddres.pop();
        uint amount = rewards.amount[tokenAddr];
        delete rewards.amount[tokenAddr];
        if (amount != 0){
            ERC20I(tokenAddr).transfer(msg.sender,amount);
        }
    }

    function nodeTokenAddresLength(address nodeAddr) public view returns (uint){
       return (_nodeRewards[nodeAddr].tokenAddres.length);
    }

    function nodeTokenAddres(address nodeAddr,uint idx) public view returns (address){
       require(_nodeRewards[nodeAddr].tokenAddres.length>idx, "No token address!");
       return (_nodeRewards[nodeAddr].tokenAddres[idx]);
    }

    function nodeTokenAmount(address nodeAddr,uint idx) public view returns (uint){
        require(_nodeRewards[nodeAddr].tokenAddres.length>idx, "No token address!");
        address tokenAddr = _nodeRewards[nodeAddr].tokenAddres[idx];
        return (_nodeRewards[nodeAddr].amount[tokenAddr]);
    }

    function feenInfo(uint requestID) public view returns (address,uint){
       ServiceFee storage fee = _serviceFees[requestID];
       return (fee.tokenAddr,fee.fee);
    }

    // For test
    function withdrawAll(uint tokenAddr) public onlyOwner{
        uint amount = ERC20I(tokenAddr).balanceOf(address(this));
        ERC20I(tokenAddr).transfer(msg.sender, amount);
    }

    function setNetworkToken(address addr) public onlyOwner {
        emit UpdateNetworkTokenAddress(networkToken, addr);
        networkToken = addr;
    }

    function setDropBurnToken(address addr) public onlyOwner {
        emit UpdateDropBurnTokenAddress(dropburnToken, addr);
        dropburnToken = addr;
    }

    function setDropBurnMaxQuota(uint quo) public onlyOwner {
        require(quo != dropburnMaxQuota && quo < 10, "Valid dropburnMaxQuota within 0 to 9");

        emit UpdateDropBurnMaxQuota(dropburnMaxQuota, quo);
        dropburnMaxQuota = quo;
    }

    // TODO: Rewrite eligibility and staking algorithm.
    function fromValidStakingNode(address node) public view returns(bool) {
        uint networkTokenBalance = ERC20I(networkToken).balanceOf(node);
        uint networkTokenDecimals = ERC20I(networkToken).decimals();
        uint minNetworkStakingBalance = minStake * (10 ** networkTokenDecimals);
        if (networkTokenBalance >= minNetworkStakingBalance) {
            return true;
        } else if (dropburnToken == address(0x0)) {
            return false;
        } else {
            uint dropburnTokenNum = ERC20I(dropburnToken).balanceOf(node) / (10 ** ERC20I(dropburnToken).decimals());
            if (dropburnTokenNum > dropburnMaxQuota) {
                dropburnTokenNum = dropburnMaxQuota;
            }
            return networkTokenBalance >= minNetworkStakingBalance * (10 - dropburnTokenNum) / 10;
        }
    }

    // TODO: Implement delegate stake, staking incentive, withdraw incentive algorithms.

}
