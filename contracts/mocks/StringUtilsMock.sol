pragma solidity ^0.5.0;

import "../lib/StringUtils.sol";

contract StringUtilsMock {
    function returnUINT256MAX() public pure returns(uint) {
        return ~uint(0);
    }

    function createByte() public pure returns(byte) {
        return '6';
    }

    function byte2Uint(byte b) public pure returns(uint8) {
        return StringUtils.byte2Uint(b);
    }

    function hexByte2Uint(byte b) public pure returns(uint8) {
        return StringUtils.hexByte2Uint(b);
    }

    function str2Uint(string memory a) public pure returns(uint) {
        return StringUtils.str2Uint(a);
    }

    function hexStr2Uint(string memory a) public pure returns(uint) {
        return StringUtils.hexStr2Uint(a);
    }

    function str2Addr(string memory a) public pure returns(address) {
        return StringUtils.str2Addr(a);
    }

    function uint2HexStr(uint x) public pure returns(string memory) {
        return StringUtils.uint2HexStr(x);
    }

    function uint2Str(uint x) public pure returns(string memory) {
        return StringUtils.uint2Str(x);
    }

    function addr2Str(string memory a) public pure returns(string memory) {
        address x = StringUtils.str2Addr(a);
        return StringUtils.addr2Str(x);
    }

    function bytesConcat(bytes memory a, bytes memory b) public pure returns(bytes memory) {
        return StringUtils.bytesConcat(a,b);
    }   

    function strConcat(string memory a, string memory b) public pure returns(string memory) {
        return StringUtils.strConcat(a,b);
    }

    function strCompare(string memory a, string memory b) public pure returns(int) {
        return StringUtils.strCompare(a, b);
    }

    function strEqual(string memory a, string memory b) public pure returns(bool) {
        return StringUtils.strEqual(a, b);
    }

    function indexOf(string memory haystack, string memory needle) public pure returns(uint) {
        return StringUtils.indexOf(haystack, needle);
    }

    function subStr(string memory a, uint start, uint len) public pure returns(string memory) {
        return StringUtils.subStr(a, start, len);
    }

    function subStr1(string memory a, uint start) public pure returns(string memory) {
        return StringUtils.subStr(a, start);
    }
}
