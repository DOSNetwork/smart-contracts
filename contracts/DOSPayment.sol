pragma solidity ^0.5.0;

import "./Ownable.sol";

contract ERC20I {
    function balanceOf(address who) public view returns (uint);
    function decimals() public view returns (uint);
    function transfer(address to, uint value) public returns (bool);
    function transferFrom(address from, address to, uint value) public returns (bool);
}

contract DOSAddressBridgeInterface {
    function getProxyAddress() public view returns (address);
}

contract DOSPayment is Ownable {
    enum ServiceType {
        SystemRandom,
        UserRandom,
        UserQuery
    }

    struct FeeList {
        // ServiceType =>serviceFee
        mapping(uint => uint) serviceFee;
        uint submitterRate;
        uint workerRate;
        uint denominator;
        uint guardianFee;
    }

    struct Payment {
        address consumer;
        address tokenAddr;
        uint serviceType;
        uint amount;
    }

    struct Rewards {
        //tokenAddr to amount
        mapping(address => uint) amount;
        address[] tokenAddres;
    }
    // consumer addr => payment token addr
    mapping(address => address) public _paymentMethods;
    //TokenAddr => feeList
    mapping(address => FeeList) public _feeList;
    // requestID => Payment
    mapping(uint => Payment) public _payments;
    // producer address => Rewards
    mapping(address => Rewards) _nodeRewards;

    uint public _defaultDenominator = 5;
    uint public _defaultSubmitterRate = 3;
    uint public _defaultWorkerRate = 2;
    uint public _defaultSystemRandomFee = 5000000000000000000; // 1 Tokens
    uint public _defaultUserRandomFee = 5000000000000000000; // 1 Tokens
    uint public _defaultUserQueryFee = 5000000000000000000; // 1 Tokens
    uint public _defaultGuardianFee = 1000000000000000000; // 1 Tokens
    address public _defaultTokenAddr;
    address public _guardianFundsAddr;
    address public _guardianFundsTokenAddr;

    // DOSAddressBridge
    DOSAddressBridgeInterface public _addressBridge;
    address public _bridgeAddr;

    event UpdateNetworkTokenAddress(address oldAddress, address newAddress);
    event UpdateDropBurnTokenAddress(address oldAddress, address newAddress);
    event LogChargeServiceFee(address consumer ,address tokenAddr,uint requestID,uint serviceType,uint fee);
    event LogRefundServiceFee(address consumer ,address tokenAddr,uint requestID,uint serviceType,uint fee);
    event LogClaimServiceFee(address nodeAddr,address tokenAddr,uint requestID,uint serviceType ,uint feeForSubmitter);
    event LogClaimGuardianFee(address nodeAddr,address tokenAddr,uint feeForSubmitter,address sender);

    modifier onlyFromProxy {
        require(msg.sender == _addressBridge.getProxyAddress(), "Not from DOS proxy!");
        _;
    }

    modifier onlySupportedToken(address tokenAddr) {
        require(isSupportedToken(tokenAddr), "Not a supported token address!");
        _;
    }

    modifier hasPayment(uint requestID) {
        require(_payments[requestID].amount!=0, "No fee infomation!");
        require(_payments[requestID].consumer!=address(0x0), "No consumer infomation!");
        require(_payments[requestID].tokenAddr!=address(0x0), "No tokenAddr infomation!");
        _;
    }

    constructor(address bridgeAddr,address guardianFundsAddr,address tokenAddr) public {
        _defaultTokenAddr = tokenAddr;
        _guardianFundsAddr = guardianFundsAddr;
        _guardianFundsTokenAddr = tokenAddr;

        FeeList storage feeList = _feeList[_defaultTokenAddr];
        feeList.serviceFee[uint(ServiceType.SystemRandom)] = _defaultSystemRandomFee;
        feeList.serviceFee[uint(ServiceType.UserRandom)] = _defaultUserRandomFee;
        feeList.serviceFee[uint(ServiceType.UserQuery)] = _defaultUserQueryFee;
        feeList.submitterRate = _defaultSubmitterRate;
        feeList.workerRate = _defaultWorkerRate;
        feeList.denominator = _defaultDenominator;
        feeList.guardianFee = _defaultGuardianFee;
        _bridgeAddr = bridgeAddr;
        _addressBridge = DOSAddressBridgeInterface(_bridgeAddr);
    }

    function isSupportedToken(address tokenAddr) public view returns(bool){
       if (tokenAddr == address(0x0)) {
           return false;
       }
       if (_feeList[tokenAddr].serviceFee[uint(ServiceType.SystemRandom)] == 0){
           return false;
       }
       if (_feeList[tokenAddr].serviceFee[uint(ServiceType.UserRandom)] == 0){
           return false;
       }
       if (_feeList[tokenAddr].serviceFee[uint(ServiceType.UserQuery)] == 0){
           return false;
       }
       return true;
    }

    function setPaymentMethod(address consumer,address tokenAddr) public onlySupportedToken(tokenAddr){
        _paymentMethods[consumer] = tokenAddr;
    }

    function setServiceFee(address tokenAddr,uint serviceType,uint fee) public onlyOwner{
        require(tokenAddr!=address(0x0), "Not a valid address!");
        FeeList storage feeList = _feeList[tokenAddr];
        feeList.serviceFee[serviceType] = fee;
    }

    function setGuardianFee(address tokenAddr,uint fee) public onlyOwner{
        require(tokenAddr!=address(0x0), "Not a valid address!");
        FeeList storage feeList = _feeList[tokenAddr];
        feeList.guardianFee = fee;
    }

    function setFeeDividend(address tokenAddr,uint submitterRate,uint workerRate,uint denominator) public onlyOwner{
        require(tokenAddr!=address(0x0), "Not a valid address!");
        FeeList storage feeList = _feeList[tokenAddr];
        feeList.submitterRate = submitterRate;
        feeList.workerRate = workerRate;
        feeList.denominator = denominator;
    }

    function setGuardianFunds(address fundsAddr,address tokenAddr) public onlyOwner onlySupportedToken(tokenAddr) {
        _guardianFundsAddr = fundsAddr;
        _guardianFundsTokenAddr = tokenAddr;
    }

    function chargeServiceFee(address consumer,uint requestID,uint serviceType) public onlyFromProxy {
        // Get tokenAddr
        address tokenAddr = _paymentMethods[consumer];
        if  (!isSupportedToken(tokenAddr)) {
            revert("Not a valid token address");
        }

        // Get fee by tokenAddr and serviceType
        uint fee = _feeList[tokenAddr].serviceFee[serviceType];

        Payment storage payment = _payments[requestID];
        payment.consumer = consumer;
        payment.serviceType = serviceType;
        payment.tokenAddr = tokenAddr;
        payment.amount = fee;

        emit LogChargeServiceFee(consumer,tokenAddr,requestID,serviceType,fee);
        ERC20I(tokenAddr).transferFrom(consumer, address(this),fee);
    }

    function refundServiceFee(uint requestID) public onlyOwner hasPayment(requestID) {
        uint fee = _payments[requestID].amount;
        uint serviceType = _payments[requestID].serviceType;
        address tokenAddr = _payments[requestID].tokenAddr;
        address consumer = _payments[requestID].consumer;
        delete _payments[requestID];
        emit LogRefundServiceFee(consumer,tokenAddr,requestID,serviceType,fee);
        ERC20I(tokenAddr).transfer(consumer,fee);
    }

    function claimServiceFee(uint requestID,address submitter,address[] memory workers) public onlyFromProxy hasPayment(requestID) {
        address tokenAddr = _payments[requestID].tokenAddr;
        uint fee = _payments[requestID].amount;
        uint serviceType = _payments[requestID].serviceType;
        delete _payments[requestID];

        // TODO : Adjust dividends strategy
        FeeList memory feeList = _feeList[tokenAddr];
        fee = fee/feeList.denominator;
        uint feeForSubmitter = fee * feeList.workerRate;
        uint feeForWorker = (fee * feeList.workerRate)/(workers.length-1);

        payFeeTo(_nodeRewards[submitter],tokenAddr,feeForSubmitter);
        emit LogClaimServiceFee(submitter,tokenAddr,requestID,serviceType,feeForSubmitter);
        for (uint i = 0; i < workers.length; i++) {
            if (workers[i] != submitter){
                payFeeTo(_nodeRewards[workers[i]],tokenAddr,feeForWorker);
                emit LogClaimServiceFee(workers[i],tokenAddr,requestID,serviceType,feeForSubmitter);
            }
        }
    }

    function payFeeTo(Rewards storage rewards,address tokenAddr,uint amount) internal{
        uint tokenAmount = rewards.amount[tokenAddr];
        if (tokenAmount == 0) {
            rewards.tokenAddres.push(tokenAddr);
        }
        rewards.amount[tokenAddr] = tokenAmount + amount;
    }

    function claimGuardianReward(address guardianAddr) public onlyFromProxy {
        require(_guardianFundsAddr!=address(0x0), "Not a valid guardian funds address!");
        require(_guardianFundsTokenAddr!=address(0x0), "Not a valid token address!");
        uint fee = _feeList[_guardianFundsTokenAddr].guardianFee;
        emit  LogClaimGuardianFee(guardianAddr,_guardianFundsTokenAddr,fee,msg.sender);
        ERC20I(_guardianFundsTokenAddr).transferFrom(_guardianFundsAddr,guardianAddr,fee);
    }

    function withdraw() public {
        require(_nodeRewards[msg.sender].tokenAddres.length!=0, "No rewards!");
        Rewards storage rewards = _nodeRewards[msg.sender];
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

    function paymentInfo(uint requestID) public view returns (address,uint){
    Payment storage payment = _payments[requestID];
       return (payment.tokenAddr,payment.amount);
    }

    // For test
    function withdrawAll(uint tokenAddr) public onlyOwner{
        uint amount = ERC20I(tokenAddr).balanceOf(address(this));
        ERC20I(tokenAddr).transfer(msg.sender, amount);
    }
}
