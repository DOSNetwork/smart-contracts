pragma solidity ^0.5.0;

contract ERC20 {
    function balanceOf(address who) public view returns (uint);
    function decimals() public view returns (uint);
    function transfer(address to, uint value) public returns (bool);
    function transferFrom(address from, address to, uint value) public returns (bool);
}

contract DOSAddressBridgeInterface {
    function getProxyAddress() public view returns (address);
}

contract DOSPayment {
    enum ServiceType {
        SystemRandom,
        UserRandom,
        UserQuery
    }

    struct FeeList {
        // ServiceType => serviceFee
        mapping(uint => uint) serviceFee;
        uint submitterCut;
        uint guardianFee;
    }

    struct Payment {
        address payer;
        address tokenAddr;
        uint serviceType;
        uint amount;
    }

    address public admin;
    // payer addr => payment token addr
    mapping(address => address) public paymentMethods;
    // tokenAddr => feeList
    mapping(address => FeeList) public feeLists;
    // requestID => Payment
    mapping(uint => Payment) public payments;
    // node address => {tokenAddr => amount}
    mapping(address => mapping(address => uint)) private _balances;

    uint constant public defaultSubmitterCut = 4;
    uint constant public defaultSystemRandomFee = 5 * 1e18;  // 5 tokens
    uint constant public defaultUserRandomFee = 5 * 1e18;    // 5 tokens
    uint constant public defaultUserQueryFee = 5 * 1e18;     // 5 tokens
    uint constant public defaultGuardianFee = 5 * 1e18;      // 5 tokens

    address public guardianFundsAddr;
    address public guardianFundsTokenAddr;
    address public bridgeAddr;
    address public defaultTokenAddr;

    event UpdatePaymentAdmin(address oldAdmin, address newAdmin);
    event LogChargeServiceFee(address payer, address tokenAddr, uint requestID, uint serviceType, uint fee);
    event LogRefundServiceFee(address payer, address tokenAddr, uint requestID, uint serviceType, uint fee);
    event LogRecordServiceFee(address nodeAddr, address tokenAddr, uint requestID, uint serviceType, uint fee, bool isSubmitter);
    event LogClaimGuardianFee(address nodeAddr, address tokenAddr, uint feeForSubmitter, address sender);

    modifier onlyFromProxy {
        require(msg.sender == DOSAddressBridgeInterface(bridgeAddr).getProxyAddress(), "not-from-dos-proxy");
        _;
    }

    modifier onlySupportedToken(address tokenAddr) {
        require(isSupportedToken(tokenAddr), "not-supported-token-addr");
        _;
    }

    modifier hasPayment(uint requestID) {
        require(payments[requestID].amount != 0, "no-fee-amount");
        require(payments[requestID].payer != address(0x0), "no-payer-info");
        require(payments[requestID].tokenAddr != address(0x0), "no-fee-token-info");
        _;
    }

    constructor(address _bridgeAddr, address _guardianFundsAddr, address _tokenAddr) public {
        initialize(_bridgeAddr, _guardianFundsAddr, _tokenAddr);
    }

    function initialize(address _bridgeAddr, address _guardianFundsAddr, address _tokenAddr) public {
        require(bridgeAddr == address(0x0) && defaultTokenAddr == address(0x0), "already-initialized");

        admin = msg.sender;
        bridgeAddr = _bridgeAddr;
        guardianFundsAddr = _guardianFundsAddr;
        guardianFundsTokenAddr = _tokenAddr;
        defaultTokenAddr = _tokenAddr;

        FeeList storage feeList = feeLists[_tokenAddr];
        feeList.serviceFee[uint(ServiceType.SystemRandom)] = defaultSystemRandomFee;
        feeList.serviceFee[uint(ServiceType.UserRandom)] = defaultUserRandomFee;
        feeList.serviceFee[uint(ServiceType.UserQuery)] = defaultUserQueryFee;
        feeList.submitterCut = defaultSubmitterCut;
        feeList.guardianFee = defaultGuardianFee;
    }

    function isSupportedToken(address tokenAddr) public view returns(bool) {
       if (tokenAddr == address(0x0)) return false;
       if (feeLists[tokenAddr].serviceFee[uint(ServiceType.SystemRandom)] == 0) return false;
       if (feeLists[tokenAddr].serviceFee[uint(ServiceType.UserRandom)] == 0) return false;
       if (feeLists[tokenAddr].serviceFee[uint(ServiceType.UserQuery)] == 0) return false;
       return true;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "onlyAdmin");
        _;
    }

    function setAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0));
        emit UpdatePaymentAdmin(admin, newAdmin);
        admin = newAdmin;
    }

    function setPaymentMethod(address payer, address tokenAddr) public onlySupportedToken(tokenAddr) {
        paymentMethods[payer] = tokenAddr;
    }

    function setServiceFee(address tokenAddr, uint serviceType, uint fee) public onlyAdmin {
        require(tokenAddr != address(0x0), "not-valid-token-addr");
        feeLists[tokenAddr].serviceFee[serviceType] = fee;
    }

    function setGuardianFee(address tokenAddr, uint fee) public onlyAdmin {
        require(tokenAddr != address(0x0), "not-valid-token-addr");
        feeLists[tokenAddr].guardianFee = fee;
    }

    function setFeeDividend(address tokenAddr, uint submitterCut) public onlyAdmin {
        require(tokenAddr != address(0x0), "not-valid-token-addr");
        feeLists[tokenAddr].submitterCut = submitterCut;
    }

    function setGuardianFunds(address fundsAddr, address tokenAddr) public onlyAdmin onlySupportedToken(tokenAddr) {
        guardianFundsAddr = fundsAddr;
        guardianFundsTokenAddr = tokenAddr;
    }

    function getServiceTypeFee(address tokenAddr, uint serviceType) public view returns(uint) {
        require(tokenAddr != address(0x0) && feeLists[tokenAddr].guardianFee != 0 && feeLists[tokenAddr].submitterCut != 0,
                "not-valid-token-addr");
        return feeLists[tokenAddr].serviceFee[serviceType];
    }

    function hasServiceFee(address payer, uint serviceType) public view returns (bool) {
        if (payer == DOSAddressBridgeInterface(bridgeAddr).getProxyAddress()) return true;
        address tokenAddr = paymentMethods[payer];
        // Get fee by tokenAddr and serviceType
        uint fee = feeLists[tokenAddr].serviceFee[serviceType];
        return ERC20(tokenAddr).balanceOf(payer) >= fee;
    }

    function chargeServiceFee(address payer, uint requestID, uint serviceType) public onlyFromProxy {
        address tokenAddr = paymentMethods[payer];
        // Get fee by tokenAddr and serviceType
        uint fee = feeLists[tokenAddr].serviceFee[serviceType];
        payments[requestID] = Payment(payer, tokenAddr, serviceType, fee);
        emit LogChargeServiceFee(payer, tokenAddr, requestID, serviceType, fee);
        ERC20(tokenAddr).transferFrom(payer, address(this), fee);
    }

    function refundServiceFee(uint requestID) public onlyAdmin hasPayment(requestID) {
        uint fee = payments[requestID].amount;
        uint serviceType = payments[requestID].serviceType;
        address tokenAddr = payments[requestID].tokenAddr;
        address payer = payments[requestID].payer;
        delete payments[requestID];
        emit LogRefundServiceFee(payer, tokenAddr, requestID, serviceType, fee);
        ERC20(tokenAddr).transfer(payer, fee);
    }

    function recordServiceFee(uint requestID, address submitter, address[] memory workers) public onlyFromProxy hasPayment(requestID) {
        address tokenAddr = payments[requestID].tokenAddr;
        uint feeUnit = payments[requestID].amount / 10;
        uint serviceType = payments[requestID].serviceType;
        delete payments[requestID];

        FeeList storage feeList = feeLists[tokenAddr];
        uint feeForSubmitter = feeUnit * feeList.submitterCut;
        _balances[submitter][tokenAddr] += feeForSubmitter;
        emit LogRecordServiceFee(submitter, tokenAddr, requestID, serviceType, feeForSubmitter, true);
        uint feeForWorker = feeUnit * (10 - feeList.submitterCut) / (workers.length - 1);
        for (uint i = 0; i < workers.length; i++) {
            if (workers[i] != submitter) {
                _balances[workers[i]][tokenAddr] += feeForWorker;
                emit LogRecordServiceFee(workers[i], tokenAddr, requestID, serviceType, feeForWorker, false);
            }
        }
    }

    function claimGuardianReward(address guardianAddr) public onlyFromProxy {
        require(guardianFundsAddr != address(0x0), "not-valid-guardian-fund-addr");
        require(guardianFundsTokenAddr != address(0x0), "not-valid-guardian-token-addr");
        uint fee = feeLists[guardianFundsTokenAddr].guardianFee;
        emit LogClaimGuardianFee(guardianAddr, guardianFundsTokenAddr, fee, msg.sender);
        ERC20(guardianFundsTokenAddr).transferFrom(guardianFundsAddr, guardianAddr,fee);
    }

    // @dev: node runners call to withdraw recorded service fees.
    function nodeClaim() public returns(uint) {
        return nodeClaim(msg.sender, defaultTokenAddr, msg.sender);
    }

    // @dev: node runners call to withdraw recorded service fees to specified address.
    function nodeClaim(address to) public returns(uint) {
        return nodeClaim(msg.sender, defaultTokenAddr, to);
    }

    function nodeClaim(address nodeAddr, address tokenAddr, address to) internal returns(uint) {
        uint amount = _balances[nodeAddr][tokenAddr];
        if (amount != 0) {
            delete _balances[nodeAddr][tokenAddr];
            ERC20(tokenAddr).transfer(to, amount);
        }
        return amount;
    }

    function nodeFeeBalance(address nodeAddr) public view returns (uint) {
        return nodeFeeBalance(nodeAddr, defaultTokenAddr);
    }

    function nodeFeeBalance(address nodeAddr, address tokenAddr) public view returns (uint) {
        return _balances[nodeAddr][tokenAddr];
    }

    function paymentInfo(uint requestID) public view returns (address, uint) {
        Payment storage payment = payments[requestID];
        return (payment.tokenAddr, payment.amount);
    }
}
