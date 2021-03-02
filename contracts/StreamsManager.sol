pragma solidity ^0.5.0;

import "./lib/StringUtils.sol";

contract IStream {
    function decimal() public view returns (uint);
    function windowSize() public view returns (uint);
    function description() public view returns (string memory);
    function selector() public view returns (string memory);
    function deviation() public view returns (uint);
    function numPoints() public view returns(uint);
    function num24hPoints() public view returns(uint);
    function hasAccess(address reader) public view returns(bool);
    function shouldUpdate(uint price) public view returns(bool);
    function megaUpdate(uint price) public returns(bool);
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
// Readable only by Data Stream UI or EOAs, not by dependant smart contracts / projects.
contract StreamsManager {
    using StringUtils for *;

    string public name;
    address public governance;
    address public pendingGovernance;
    // Valid index starts from 1.
    address[] public _streams;
    // sorted streams according to stream.description()
    address[] private _sortedStreams;
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
        require(msg.sender == tx.origin, "!accessible-by-non-eoa");
        _;
    }
    modifier onlyMegaStream {
        require(msg.sender == _streams[0], "!from-megaStream");
        _;
    }

    constructor(string memory _name, address megaStream) public {
        name = _name;
        governance = msg.sender;
        _streams.push(megaStream);
        streamsIdx[megaStream] = 0;
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
    function quickSortBySelector(address[] memory arr, uint left, uint right) public view {
        if (left >= right) return;
        // p = the pivot element
        address p = arr[(left + right) / 2];
        uint i = left;
        uint j = right;
        while (i < j) {
            while (IStream(arr[i]).selector().strCompare(IStream(p).selector()) < 0) ++i;
            // arr[j] > p means p still to the left, so j > 0
            while (IStream(arr[j]).selector().strCompare(IStream(p).selector()) > 0) --j;
            if (IStream(arr[i]).selector().strCompare(IStream(arr[j]).selector()) > 0)
                (arr[i], arr[j]) = (arr[j], arr[i]);
            else
                ++i;
        }

        // Note --j was only done when a[j] > p.  So we know: a[j] == p, a[<j] <= p, a[>j] > p
        if (j > left) quickSortBySelector(arr, left, j - 1); // j > left, so j > 0
        quickSortBySelector(arr, j + 1, right);
    }
    function sortStreams() private {
        address[] memory s = new address[](_streams.length - 1);
        for (uint i = 1; i < _streams.length; i++) {
            s[i-1] = _streams[i];
        }
        quickSortBySelector(s, 0, s.length - 1);
        _sortedStreams = s;
    }
    function sortedStreams() public view returns(address[] memory) {
        return _sortedStreams;
    }
    function addStream(address stream) public onlyGovernance {
        require(streamsIdx[stream] == 0, "existed");
        _streams.push(stream);
        streamsIdx[stream] = _streams.length - 1;
        emit StreamAdded(stream, _streams.length - 1);
        sortStreams();
    }
    function updateStream(address stream, address newStream) public onlyGovernance {
        require(streamsIdx[stream] != 0, "!exist");
        require(streamsIdx[newStream] == 0, "existed");
        _streams[streamsIdx[stream]] = newStream;
        streamsIdx[newStream] = streamsIdx[stream];
        delete streamsIdx[stream];
        emit StreamAddressUpdated(stream, newStream);
        sortStreams();
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
        sortStreams();
    }

    function megaUpdate(uint[] calldata data) external onlyMegaStream returns(bool) {
        bool ret = false;
        for (uint i = 0; i < data.length; i++) {
            ret = IStream(_sortedStreams[i]).megaUpdate(data[i]) || ret;
        }
        return ret;
    }

    function streams() public view returns(address[] memory) {
        return _streams;
    }

    function decimal(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).decimal();
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
    function num24hPoints(address stream) public view accessible(stream) returns(uint) {
        return IStream(stream).num24hPoints();
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
