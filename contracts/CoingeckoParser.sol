pragma solidity ^0.5.0;

import "./lib/SafeMath.sol";
import "./lib/StringUtils.sol";

// A simple parser to parse coingecko api data.
// Coingecko data api: https://www.coingecko.com/en/api.
// e.g. source:   "https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=ethereum,bitcoin,polkadot,huobi-token"
// e.g. selector: "$.ethereum.usd"
contract Parser {
    using StringUtils for string;
    using SafeMath for uint;

    string public constant description = "Coingecko API Data Parser V1";
    uint private constant ten = 10;
    
    // e.g.:
    //   parse("123.4567", 0) => 123
    //   parse("123.4567", 2) => 12345
    //   parse("123.4567", 8) => 12345670000
    function parse(string memory raw, uint decimal) public pure returns(uint) {
        uint integral = raw.str2Uint();
        uint fractional = 0;
        int dotIdx = raw.indexOf('.');
        uint fracIdx = uint(dotIdx + 1);
        if (dotIdx != -1 && fracIdx < bytes(raw).length) {
            string memory fracStr = raw.subStr(fracIdx, decimal);
            fractional = fracStr.str2Uint();
            if (decimal > bytes(fracStr).length) {
                fractional = fractional.mul(ten.pow(decimal - bytes(fracStr).length));
            }
        }
        return integral.mul(ten.pow(decimal)).add(fractional);
    }
}
