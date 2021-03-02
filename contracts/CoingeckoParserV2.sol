pragma solidity ^0.5.0;

import "./lib/SafeMath.sol";
import "./lib/StringUtils.sol";

// A simple parser to parse coingecko api data.
// Coingecko data api: https://www.coingecko.com/en/api.
// e.g. source:   "https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=ethereum,bitcoin,polkadot,huobi-token"
// e.g. selector: "$..usd"
// e.g. Return:   "[48766,1524.21,13.99,34.64]"
contract CoingeckoParserV2 {
    using StringUtils for *;
    using SafeMath for uint;

    string public constant description = "Coingecko API Data Parser V2";
    uint private constant ten = 10;

    // e.g.:
    //   floatStr2Uint("123.4567", 0) => 123
    //   floatStr2Uint("123.4567", 2) => 12345
    //   floatStr2Uint("123.4567", 8) => 12345670000
    function floatStr2Uint(string memory raw, uint decimal) public pure returns(uint) {
        uint integral = raw.str2Uint();
        uint fractional = 0;
        uint dotIdx = raw.indexOf('.');
        uint fracIdx = dotIdx + 1;
        if (dotIdx != bytes(raw).length && fracIdx < bytes(raw).length) {
            string memory fracStr = raw.subStr(fracIdx, decimal);
            fractional = fracStr.str2Uint();
            if (decimal > bytes(fracStr).length) {
                fractional = fractional.mul(ten.pow(decimal - bytes(fracStr).length));
            }
        }
        return integral.mul(ten.pow(decimal)).add(fractional);
    }

    function floatBytes2UintArray(bytes memory raw, uint decimal) public pure returns (uint[] memory) {
        uint len = raw.length;
        string[] memory s_arr = string(raw.subStr(1, len - 2)).split(',');
        uint[] memory uint_arr = new uint[](s_arr.length);
        for (uint i = 0; i < s_arr.length; i++) {
            uint_arr[i] = floatStr2Uint(s_arr[i], decimal);
        }
        return uint_arr;
    }

    function floatStrs2UintArray(string memory raw, uint decimal) public pure returns (uint[] memory) {
        return floatBytes2UintArray(bytes(raw), decimal);
    }
}
