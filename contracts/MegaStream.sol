pragma solidity ^0.5.0;

import "./DOSOnChainSDK.sol";

contract IParser {
    function floatBytes2UintArray(bytes memory raw, uint decimal) public view returns(uint[] memory);
}

contract IStreamsManager {
    function megaUpdate(uint[] calldata data) external returns(bool);
}

contract MegaStream is DOSOnChainSDK {
    uint public windowSize = 1200;     // 20 minutes
    // Number of decimals the reported price data use.
    uint public decimal;
    uint public lastTime;
    string public megaDescription;
    string public megaSource;
    string public megaSelector;
    // Data parser, may be configured along with data source change
    address public parser;
    address public streamsManager;
    // Stream data is either updated once per windowSize or the deviation requirement is met, whichever comes first.
    // Anyone can trigger an update on windowSize expiration, but only governance approved ones can be deviation updater to get rid of sybil attacks.
    mapping(address => bool) private deviationGuardian;
    mapping(uint => bool) private _valid;
    
    event ParamsUpdated(
        string oldDescription, string newDescription,
        string oldSource, string newSource,
        string oldSelector, string newSelector,
        uint oldDecimal, uint newDecimal
    );
    event WindowUpdated(uint oldWindow, uint newWindow);
    event ParserUpdated(address oldParser, address newParser);
    event ManagerUpdated(address oldParser, address newParser);
    event DataUpdated(uint timestamp, uint price);
    event PulledTrigger(address trigger, uint qId);
    event BulletCaught(uint qId);
    event AddGuardian(address guardian);
    event RemoveGuardian(address guardian);

    modifier isContract(address addr) {
        uint codeSize = 0;
        assembly {
            codeSize := extcodesize(addr)
        }
        require(codeSize > 0, "not-smart-contract");
        _;
    }

    constructor(
        string memory _description,
        string memory _source,
        string memory _selector,
        uint _decimal,
        address _parser
    )
        public
        isContract(_parser)
    {
        // @dev: setup and then transfer DOS tokens into deployed contract
        // as oracle fees.
        // Unused fees can be reclaimed by calling DOSRefund() function of SDK contract.
        super.DOSSetup();
        megaDescription = _description;
        megaSource = _source;
        megaSelector = _selector;
        decimal = _decimal;
        parser = _parser;
        emit ParamsUpdated("", _description, "", _source, "", _selector, 0, _decimal);
        emit ParserUpdated(address(0), _parser);
    }
    
    function strEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function updateWindowSize(uint newWindow) public onlyOwner {
        emit WindowUpdated(windowSize, newWindow);
        windowSize = newWindow;
    }
    function updateParams(string memory _description, string memory _source, string memory _selector, uint _decimal) public onlyOwner {
        emit ParamsUpdated(
            megaDescription, _description,
            megaSource, _source,
            megaSelector, _selector,
            decimal, _decimal
        );
        if (!strEqual(megaDescription, _description)) megaDescription = _description;
        if (!strEqual(megaSource, _source)) megaSource = _source;
        if (!strEqual(megaSelector, _selector)) megaSelector = _selector;
        if (decimal != _decimal) decimal = _decimal;
    }
    function updateParser(address newParser) public onlyOwner isContract(newParser) {
        emit ParserUpdated(parser, newParser);
        parser = newParser;
    }
    function updateManager(address _manager) public onlyOwner isContract(_manager) {
        emit ManagerUpdated(streamsManager, _manager);
        streamsManager = _manager;
    }
    function addGuardian(address guardian) public onlyOwner {
        if (!deviationGuardian[guardian]) {
            deviationGuardian[guardian] = true;
            emit AddGuardian(guardian);
        }
    }
    function removeGuardian(address guardian) public onlyOwner {
        if (deviationGuardian[guardian]) {
            delete deviationGuardian[guardian];
            emit RemoveGuardian(guardian);
        }
    }

    function pullTrigger() public {
        if(lastTime + windowSize >= block.timestamp && !deviationGuardian[msg.sender]) return;

        uint id = DOSQuery(30, megaSource, megaSelector);
        if (id != 0) {
            _valid[id] = true;
            emit PulledTrigger(msg.sender, id);
        }
    }

    function __callback__(uint id, bytes calldata result) external auth {
        require(_valid[id], "invalid-request-id");
        uint[] memory prices = IParser(parser).floatBytes2UintArray(result, decimal);
        if (IStreamsManager(streamsManager).megaUpdate(prices)) emit BulletCaught(id);
        delete _valid[id];
        lastTime = block.timestamp;
    }
}
