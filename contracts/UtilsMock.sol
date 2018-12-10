pragma solidity >= 0.4.24;
import "./lib/Utils.sol";

contract UtilsMock {
    function returnUINT256MAX() public pure returns(uint) {
        return ~uint(0);
    }

    function createByte() public pure returns(byte) {
        return '6';
    }

    function byte2Uint(byte b) public pure returns(uint8) {
        return Utils.byte2Uint(b);
    }

    function hexByte2Uint(byte b) public pure returns(uint8) {
        return Utils.hexByte2Uint(b);
    }

    function str2Uint(string memory a) public pure returns(uint) {
        return Utils.str2Uint(a);
    }

    function hexStr2Uint(string memory a) public pure returns(uint) {
        return Utils.hexStr2Uint(a);
    }

    function str2Addr(string memory a) public pure returns(address) {
        return Utils.str2Addr(a);
    }

    function uint2HexStr(uint x) public pure returns(string memory) {
        return Utils.uint2HexStr(x);
    }

    function uint2Str(uint x) public pure returns(string memory) {
        return Utils.uint2Str(x);
    }

    function addr2Str(string memory a) public pure returns(string memory) {
        address x = str2Addr(a); 
        return Utils.addr2Str(x);
    }

    // function bytesConcat(bytes memory a, bytes memory b) public pure returns(bytes memory) {
    //     return Utils.bytesConcat(a,b);
    // }   

    function strConcat(string memory a, string memory b) public pure returns(string memory) {
        return Utils.strConcat(a,b);
    }

    // function bytesCompare(bytes memory a, bytes memory b) public pure returns(int) {
    //     return Utils.bytesCompare(a, b);
    // }

    function strCompare(string memory a, string memory b) public pure returns(int) {
        return Utils.strCompare(a, b);
    }

    // function bytesEqual(bytes memory a, bytes memory b) public pure returns (bool) {
    //     return Utils.bytesEqual(a, b);
    // }

    function strEqual(string memory a, string memory b) public pure returns(bool) {
        return Utils.strEqual(a, b);
    }

    function indexOf(string memory haystack, string memory needle) public pure returns(int) {
        return Utils.indexOf(haystack, needle);
    }

    // function indexOf(bytes memory haystack, bytes memory needle) public pure returns(int) {
    //     return Utils.indexOf(haystack, needle);
    // }

    // function subStr(bytes memory a, uint start, uint len) public pure returns(bytes memory) {
    //     return Utils.subStr(a, start, len);
    // }

    // function subStr(bytes memory a, uint start) public pure returns(bytes memory) {
    //     return Utils.subStr(a, start);
    // }

    function subStr(string memory a, uint start, uint len) public pure returns(string memory) {
        return Utils.subStr(a, start, len);
    }

    function subStr1(string memory a, uint start) public pure returns(string memory) {
        return Utils.subStr(a, start);
    }
}