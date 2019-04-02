pragma solidity ^0.5.0;

//import "github.com/DOSNetwork/eth-contracts/contracts/DOSOnChainSDK.sol";
import "../DOSOnChainSDK.sol";

// An example get latest ETH-USD price from Coinbase
contract CoinbaseEthUsd is DOSOnChainSDK {
    // Struct to hold parsed floating string "123.45"
    struct ethusd {
        uint integral;
        uint fractional;
    }
    uint queryId;
    string public price_str;
    ethusd public prices;
    
    event GetPrice(uint integral, uint fractional);
    
    function check() public {
        queryId = DOSQuery(30, "https://api.coinbase.com/v2/prices/ETH-USD/spot", "$.data.amount");
    }
    
    modifier auth {
        // Filter out malicious __callback__ callers.
        require(msg.sender == fromDOSProxyContract(), "Unauthenticated response");
        _;
    }
    
    function __callback__(uint id, bytes memory result) public auth {
        require(queryId == id, "Unmatched response");
        
        price_str = string(result);
        prices.integral = price_str.subStr(1).str2Uint();
        int delimit_idx = price_str.indexOf('.');
        if (delimit_idx != -1) {
            prices.fractional = price_str.subStr(uint(delimit_idx + 1)).str2Uint();
        }
        emit GetPrice(prices.integral, prices.fractional);
    }
}
