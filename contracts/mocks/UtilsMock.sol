pragma solidity ^0.5.0;

import "../lib/utils.sol";

contract UtilsMock {
    function returnUINT256MAX() public pure returns(uint) {
        return ~uint(0);
    }

    function createByte() public pure returns(byte) {
        return '6';
    }

    function byte2Uint(byte b) public pure returns(uint8) {
        return utils.byte2Uint(b);
    }

    function hexByte2Uint(byte b) public pure returns(uint8) {
        return utils.hexByte2Uint(b);
    }

    function str2Uint(string memory a) public pure returns(uint) {
        return utils.str2Uint(a);
    }

    function hexStr2Uint(string memory a) public pure returns(uint) {
        return utils.hexStr2Uint(a);
    }

    function str2Addr(string memory a) public pure returns(address) {
        return utils.str2Addr(a);
    }

    function uint2HexStr(uint x) public pure returns(string memory) {
        return utils.uint2HexStr(x);
    }

    function uint2Str(uint x) public pure returns(string memory) {
        return utils.uint2Str(x);
    }

    function addr2Str(string memory a) public pure returns(string memory) {
        address x = utils.str2Addr(a);
        return utils.addr2Str(x);
    }

    function bytesConcat(bytes memory a, bytes memory b) public pure returns(bytes memory) {
        return utils.bytesConcat(a,b);
    }   

    function strConcat(string memory a, string memory b) public pure returns(string memory) {
        return utils.strConcat(a,b);
    }

    function strCompare(string memory a, string memory b) public pure returns(int) {
        return utils.strCompare(a, b);
    }

    function strEqual(string memory a, string memory b) public pure returns(bool) {
        return utils.strEqual(a, b);
    }

    function indexOf(string memory haystack, string memory needle) public pure returns(int) {
        return utils.indexOf(haystack, needle);
    }

    function subStr(string memory a, uint start, uint len) public pure returns(string memory) {
        return utils.subStr(a, start, len);
    }

    function subStr1(string memory a, uint start) public pure returns(string memory) {
        return utils.subStr(a, start);
    }
}
