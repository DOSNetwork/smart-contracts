pragma solidity ^0.5.0;

contract IStream {
    function decimals() public view returns (uint);
    function windowSize() public view returns (uint);
    function description() public view returns (string memory);
    function deviation() public view returns (uint);
    function numPoints() public view returns(uint);
    function hasAccess(address reader) public view returns(bool);
    function latestResult() public view returns (uint, uint);
    function TWAP1Hour() public view returns (uint);
    function TWAP2Hour() public view returns (uint);
    function TWAP4Hour() public view returns (uint);
    function TWAP6Hour() public view returns (uint);
    function TWAP8Hour() public view returns (uint);
    function TWAP12Hour() public view returns (uint);
    function TWAP1Day() public view returns (uint);
    function TWAP1Week() public view returns (uint);
}

// StreamsManager manages group of data streams from the same meta data source (e.g. Coingecko, Coinbase, etc.)
// Mostly used by Data Stream UI, not by dependant projects / devs.
contract StreamsManager {
    string public name;
    address public governance;
    address public pendingGovernance;
    // Valid index starts from 1.
    address[] public _streams;
    // stream => index in streams array
    mapping(address=>uint) public streamsIdx;

    event GovernanceProposed(address pendingGov);
    event GovernanceAccepted(address newGov);
    event StreamAdded(address stream, uint numStreams);
    event StreamAddressUpdated(address oldStreamAddr, address newStreamAddr);
    event StreamRemoved(address stream);

    modifier onlyGovernance {
        require(msg.sender == governance, "!governance");
        _;
    }
    modifier accessible(address stream) {
        require(streamsIdx[stream] != 0 && stream == _streams[streamsIdx[stream]], "!exist");
        require(IStream(stream).hasAccess(msg.sender), "!accessible");
        _;
    }

    constructor(string memory _name) public {
        name = _name;
        governance = msg.sender;
        _streams.push(address(0));
    }

    function setGovernance(address _governance) public onlyGovernance {
        pendingGovernance = _governance;
        emit GovernanceProposed(_governance);
    }
    function acceptGovernance() public {
        require(msg.sender == pendingGovernance, "!pendingGovernance");
        governance = pendingGovernance;
        pendingGovernance = address(0);
        emit GovernanceAccepted(governance);
    }
    function addStream(address stream) public onlyGovernance {
        require(streamsIdx[stream] == 0, "existed");
        _streams.push(stream);
        streamsIdx[stream] = _streams.length - 1;
        emit StreamAdded(stream, _streams.length - 1);
    }
    function updateStream(address stream, address newStream) public onlyGovernance {
        require(streamsIdx[stream] != 0, "!exist");
        require(streamsIdx[newStream] == 0, "existed");
        _streams[streamsIdx[stream]] = newStream;
        streamsIdx[newStream] = streamsIdx[stream];
        delete streamsIdx[stream];
        emit StreamAddressUpdated(stream, newStream);
    }
    function removeStream(address stream) public onlyGovernance {
        uint streamId = streamsIdx[stream];
        require(streamId != 0, "!exist");
        if (_streams.length > 2) {
            _streams[streamId] = _streams[_streams.length - 1];
            streamsIdx[_streams[streamId]] = streamId;
        }
        _streams.length--;
        delete streamsIdx[stream];
        emit StreamRemoved(stream);
    }

    function streams() public view returns(address[] memory) {
        return _streams;
    }

    function decimal(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).decimals();
    }
    function windowSize(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).windowSize();
    }
    function description(address stream) public view accessible(stream) returns(string memory) {
        return IStream(stream).description();
    }
    function deviation(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).deviation();
    }
    function numPoints(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).numPoints();
    }
    function latestResult(address stream) public view accessible(stream) returns(uint, uint) {
        return IStream(stream).latestResult();
    }
    function TWAP1Hour(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).TWAP1Hour();
    }
    function TWAP2Hour(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).TWAP2Hour();
    }
    function TWAP4Hour(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).TWAP4Hour();
    }
    function TWAP6Hour(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).TWAP6Hour();
    }
    function TWAP8Hour(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).TWAP8Hour();
    }
    function TWAP12Hour(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).TWAP12Hour();
    }
    function TWAP1Day(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).TWAP1Day();
    }
    function TWAP1Week(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).TWAP1Week();
    }
}
