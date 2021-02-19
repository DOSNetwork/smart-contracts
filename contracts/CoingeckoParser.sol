pragma solidity ^0.5.0;

// A simple parser to parse coingecko api data.
// Coingecko data api: https://www.coingecko.com/en/api.
// e.g. source:   "https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=ethereum,bitcoin,polkadot,huobi-token"
// e.g. selector: "$.ethereum.usd"
contract Parser {
    string public constant description = "Coingecko API Data Parser V1";
    
    function parse(string memory raw, uint decimal) public view returns(uint) {
        
    }
}
