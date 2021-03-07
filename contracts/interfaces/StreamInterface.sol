pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

interface IStream {
    struct Observation {
        uint timestamp;
        uint price;
    }
    function description() external view returns (string memory);
    function decimal() external view returns (uint);
    function windowSize() external view returns (uint);
    function source() external view returns (string memory);
    function selector() external view returns (string memory);
    function deviation() external view returns (uint);
    function numPoints() external view returns(uint);
    function num24hPoints() external view returns(uint);
    function latestResult() external view returns (uint lastPrice, uint lastUpdatedTime);
    function result(uint idx) external view returns (uint price, uint timestamp);
    function results(uint startIdx, uint lastIdx) external view returns(Observation[] memory);
    function last24hResults() external view returns (Observation[] memory);
    function shouldUpdate(uint price) external view returns(bool);
    function megaUpdate(uint price) external returns(bool);
    function TWAP1Hour() external view returns (uint);
    function TWAP2Hour() external view returns (uint);
    function TWAP4Hour() external view returns (uint);
    function TWAP6Hour() external view returns (uint);
    function TWAP8Hour() external view returns (uint);
    function TWAP12Hour() external view returns (uint);
    function TWAP1Day() external view returns (uint);
    function TWAP1Week() external view returns (uint);
}
