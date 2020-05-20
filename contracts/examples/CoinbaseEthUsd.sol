pragma solidity ^0.5.0;

import "../lib/utils.sol";
import "../DOSOnChainSDK.sol";

// An example get latest ETH-USD price from Coinbase
contract CoinbaseEthUsd is DOSOnChainSDK {
    using utils for *;

    // Struct to hold parsed floating string "123.45"
    struct ethusd {
        uint integral;
        uint fractional;
    }
    uint queryId;
    string public price_str;
    ethusd public prices;

    event GetPrice(uint integral, uint fractional);

    constructor() public {
        // @dev: setup() and then transfer DOS tokens into deployed contract
        // as oracle fees.
        // Unused fees can be reclaimed by calling refund() in the SDK.
        super.setup();
    }

    function check() public {
        queryId = DOSQuery(30, "https://api.coinbase.com/v2/prices/ETH-USD/spot", "$.data.amount");
    }

    function __callback__(uint id, bytes calldata result) external auth {
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
