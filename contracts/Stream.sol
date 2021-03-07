pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./lib/SafeMath.sol";
import "./DOSOnChainSDK.sol";

contract IParser {
    function floatBytes2UintArray(bytes memory raw, uint decimal) public view returns(uint[] memory);
}

contract Stream is DOSOnChainSDK {
    using SafeMath for uint;

    uint private constant ONEHOUR = 1 hours;
    uint private constant ONEDAY = 1 days;
    // overflow flag
    uint private constant UINT_MAX = uint(-1);
    uint public windowSize = 1200;     // 20 minutes
    // e.g. ETH / USD
    string public description;
    string public source;
    string public selector;
    uint public sId;
    // Absolute price deviation percentage * 1000, i.e. 1 represents 1/1000 price change.
    uint public deviation = 5;
    // Number of decimals the reported price data use.
    uint public decimal;
    // Data parser, may be configured along with data source change
    address public parser;
    address public streamManager;
    bool public whitelistEnabled;
    // Reader whitelist
    mapping(address => bool) private whitelist;
    // Stream data is either updated once per windowSize or the deviation requirement is met, whichever comes first.
    // Anyone can trigger an update on windowSize expiration, but only governance approved ones can be deviation updater to get rid of sybil attacks.
    mapping(address => bool) private deviationGuardian;
    mapping(uint => bool) private _valid;

    struct Observation {
        uint timestamp;
        uint price;
    }
    Observation[] private observations;
    
    event ParamsUpdated(
        string oldDescription, string newDescription,
        string oldSource, string newSource,
        string oldSelector, string newSelector,
        uint oldDecmial, uint newDecimal
    );
    event WindowUpdated(uint oldWindow, uint newWindow);
    event DeviationUpdated(uint oldDeviation, uint newDeviation);
    event ParserUpdated(address oldParser, address newParser);
    event DataUpdated(uint timestamp, uint price);
    event PulledTrigger(address trigger, uint qId);
    event BulletCaught(uint qId);
    event AddAccess(address reader);
    event RemoveAccess(address reader);
    event AccessStatusUpdated(bool oldStatus, bool newStatus);
    event AddGuardian(address guardian);
    event RemoveGuardian(address guardian);

    modifier accessible {
        require(!whitelistEnabled || hasAccess(msg.sender), "!accessible");
        _;
    }

    modifier isContract(address addr) {
        uint codeSize = 0;
        assembly {
            codeSize := extcodesize(addr)
        }
        require(codeSize > 0, "not-smart-contract");
        _;
    }

    modifier onlyUpdater {
        require(msg.sender == streamManager, "!updater");
        _;
    }

    constructor(
        string memory _description,
        string memory _source,
        string memory _selector,
        uint _decimal,
        address _parser,
        address _manager
    )
        public
        isContract(_parser)
        isContract(_manager)
    {
        // @dev: setup and then transfer DOS tokens into deployed contract
        // as oracle fees.
        // Unused fees can be reclaimed by calling DOSRefund() function of SDK contract.
        super.DOSSetup();
        description = _description;
        source = _source;
        selector = _selector;
        decimal = _decimal;
        parser = _parser;
        streamManager = _manager;
        addReader(_manager);
        emit ParamsUpdated("", _description, "", _source, "", _selector, 0, _decimal);
        emit ParserUpdated(address(0), _parser);
    }
    
    function strEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function updateParams(string memory _description, string memory _source, string memory _selector, uint _decimal, uint _sId) public onlyOwner {
        emit ParamsUpdated(
            description, _description,
            source, _source,
            selector, _selector,
            decimal, _decimal
        );
        if (!strEqual(description, _description)) description = _description;
        if (!strEqual(source, _source)) source = _source;
        if (!strEqual(selector, _selector)) selector = _selector;
        if (decimal != _decimal) decimal = _decimal;
        if (sId != _sId) sId = _sId;
    }
    // This will erase all observed data!
    function updateWindowSize(uint newWindow) public onlyOwner {
        emit WindowUpdated(windowSize, newWindow);
        windowSize = newWindow;
        observations.length = 0;
    }
    function updateDeviation(uint newDeviation) public onlyOwner {
        require(newDeviation >= 0 && newDeviation <= 1000, "should-be-in-0-1000");
        emit DeviationUpdated(deviation, newDeviation);
        deviation = newDeviation;
    }
    function updateParser(address newParser) public onlyOwner isContract(newParser) {
        emit ParserUpdated(parser, newParser);
        parser = newParser;
    }
    function addReader(address reader) public onlyOwner {
        if (!whitelist[reader]) {
            whitelist[reader] = true;
            emit AddAccess(reader);
        }
    }
    function removeReader(address reader) public onlyOwner {
        if (whitelist[reader]) {
            delete whitelist[reader];
            emit RemoveAccess(reader);
        }
    }
    function toggleAccessStatus() public onlyOwner {
        emit AccessStatusUpdated(whitelistEnabled, !whitelistEnabled);
        whitelistEnabled = !whitelistEnabled;
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

    function hasAccess(address reader) public view returns(bool) {
        return whitelist[reader] || reader == tx.origin;
    }

    function numPoints() public view returns(uint) {
        return observations.length;
    }
    function num24hPoints() public view returns(uint) {
        uint idx = binarySearch(ONEDAY);
        if (idx == UINT_MAX) return observations.length;
        return observations.length - idx;
    }

    // Observation[] is sorted by timestamp in ascending order. Return the maximum index {i}, satisfying that: observations[i].timestamp <= observations[end].timestamp.sub(timedelta)
    // Return UINT_MAX if not enough data points.
    function binarySearch(uint timedelta) public view returns (uint) {
        if (observations.length == 0) return uint(-1);

        int index = -1;
        int l = 0;
        int r = int(observations.length.sub(1));
        uint key = observations[uint(r)].timestamp.sub(timedelta);
        while (l <= r) {
            int m = (l + r) / 2;
            uint m_val = observations[uint(m)].timestamp;
            if (m_val <= key) {
                index = m;
                l = m + 1;
            } else {
                r = m - 1;
            }
        }
        return uint(index);
    }

    function stale(uint age) public view returns(bool) {
        uint lastTime = observations.length > 0 ? observations[observations.length - 1].timestamp : 0;
        return block.timestamp > lastTime.add(age);
    }

    function pullTrigger() public {
        if(!stale(windowSize) && !deviationGuardian[msg.sender]) return;

        uint id = DOSQuery(30, source, selector);
        if (id != 0) {
            _valid[id] = true;
            emit PulledTrigger(msg.sender, id);
        }
    }

    function __callback__(uint id, bytes calldata result) external auth {
        require(_valid[id], "invalid-request-id");
        uint[] memory priceData = IParser(parser).floatBytes2UintArray(result, decimal);
        if (update(priceData[sId])) emit BulletCaught(id);
        delete _valid[id];
    }

    function shouldUpdate(uint price) public view returns(bool) {
        uint lastPrice = observations.length > 0 ? observations[observations.length - 1].price : 0;
        uint delta = price > lastPrice ? (price - lastPrice) : (lastPrice - price);
        return stale(windowSize) || (deviation > 0 && delta >= lastPrice.mul(deviation).div(1000));
    }

    function update(uint price) private returns(bool) {
        if (shouldUpdate(price)) {
            observations.push(Observation(block.timestamp, price));
            emit DataUpdated(block.timestamp, price);
            return true;
        }
        return false;
    }

    function megaUpdate(uint price) public onlyUpdater returns(bool) {
        return update(price);
    }

    // @dev Returns any specific historical data point.
    // Accessible by whitelisted contracts or EOA user.
    function result(uint idx) public view accessible returns (uint _price, uint _timestamp) {
        require(idx < observations.length);
        return (observations[idx].price, observations[idx].timestamp);
    }
    
    // @dev Returns data [observations[startIdx], observations[lastIdx]], inclusive.
    function results(uint startIdx, uint lastIdx) public view accessible returns (Observation[] memory) {
        require(startIdx <= lastIdx && lastIdx < observations.length);
        Observation[] memory ret = new Observation[](lastIdx - startIdx + 1);
        for (uint i = startIdx; i <= lastIdx; i++) {
            ret[i - startIdx] = observations[i];
        }
        return ret;
    }
    function last24hResults() public view accessible returns (Observation[] memory) {
        uint lastIdx = observations.length - 1;
        uint startIdx = binarySearch(ONEDAY);
        if (startIdx == UINT_MAX) startIdx = observations.length - 1;
        return results(startIdx, lastIdx);
    }

    // @dev Returns the most freshed (latest reported) data point.
    // Accessible by whitelisted contracts or EOA.
    // Return latest reported price & timestamp data.
    function latestResult() public view accessible returns (uint _lastPrice, uint _lastUpdatedTime) {
        require(observations.length > 0);
        Observation storage last = observations[observations.length - 1];
        return (last.price, last.timestamp);
    }
    
    // @dev Returns time-weighted average price (TWAP) of (observations[start] : observations[end]).
    // Accessible by whitelisted contracts or EOA.
    function twapResult(uint start) public view accessible returns (uint) {
        require(start < observations.length, "index-overflow");
        
        uint end = observations.length - 1;
        uint cumulativePrice = 0;
        for (uint i = start; i < end; i++) {
            cumulativePrice = cumulativePrice.add(observations[i].price.mul(observations[i+1].timestamp.sub(observations[i].timestamp)));
        }
        uint timeElapsed = observations[end].timestamp.sub(observations[start].timestamp);
        return cumulativePrice.div(timeElapsed);
    }
    
    // @dev Below are a series of inhouse TWAP functions for the ease of developers.
    // Accessible by whitelisted contracts or EOA user.
    // More TWAP functions can be built by the above twapResult(startIdx) function.
    function TWAP1Hour() public view accessible returns (uint) {
        require(!stale(ONEHOUR), "1h-outdated-data");
        uint idx = binarySearch(ONEHOUR);
        require(idx != UINT_MAX, "not-enough-observation-data-for-1h");
        return twapResult(idx);
    }
    
    function TWAP2Hour() public view accessible returns (uint) {
        require(!stale(ONEHOUR * 2), "2h-outdated-data");
        uint idx = binarySearch(ONEHOUR * 2);
        require(idx != UINT_MAX, "not-enough-observation-data-for-2h");
        return twapResult(idx);
    }
    
    function TWAP4Hour() public view accessible returns (uint) {
        require(!stale(ONEHOUR * 4), "4h-outdated-data");
        uint idx = binarySearch(ONEHOUR * 4);
        require(idx != UINT_MAX, "not-enough-observation-data-for-4h");
        return twapResult(idx);
    }

    function TWAP6Hour() public view accessible returns (uint) {
        require(!stale(ONEHOUR * 6), "6h-outdated-data");
        uint idx = binarySearch(ONEHOUR * 6);
        require(idx != UINT_MAX, "not-enough-observation-data-for-6h");
        return twapResult(idx);
    }

    function TWAP8Hour() public view accessible returns (uint) {
        require(!stale(ONEHOUR * 8), "8h-outdated-data");
        uint idx = binarySearch(ONEHOUR * 8);
        require(idx != UINT_MAX, "not-enough-observation-data-for-8h");
        return twapResult(idx);
    }
    
    function TWAP12Hour() public view accessible returns (uint) {
        require(!stale(ONEHOUR * 12), "12h-outdated-data");
        uint idx = binarySearch(ONEHOUR * 12);
        require(idx != UINT_MAX, "not-enough-observation-data-for-12h");
        return twapResult(idx);
    }
    
    function TWAP1Day() public view accessible returns (uint) {
        require(!stale(ONEDAY), "1d-outdated-data");
        uint idx = binarySearch(ONEDAY);
        require(idx != UINT_MAX, "not-enough-observation-data-for-1d");
        return twapResult(idx);
    }
    
    function TWAP1Week() public view accessible returns (uint) {
        require(!stale(ONEDAY * 7), "1w-outdated-data");
        uint idx = binarySearch(ONEDAY * 7);
        require(idx != UINT_MAX, "not-enough-observation-data-for-1week");
        return twapResult(idx);
    }
}
