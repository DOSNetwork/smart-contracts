pragma solidity ^0.5.0;

import "./Ownable.sol";

contract IProxy {
    function query(address, uint, string memory, string memory) public returns (uint);
    function requestRandom(address, uint) public returns (uint);
}

contract IPayment {
    function setPaymentMethod(address payer, address tokenAddr) public;
    function defaultTokenAddr() public returns(address);
}

contract IAddressBridge {
    function getProxyAddress() public view returns (address);
    function getPaymentAddress() public view returns (address);
}

contract IERC20 {
    function balanceOf(address who) public view returns (uint);
    function transfer(address to, uint value) public returns (bool);
    function approve(address spender, uint value) public returns (bool);
}

contract DOSOnChainSDK is Ownable {
    IProxy dosProxy;
    IAddressBridge dosAddrBridge = IAddressBridge(0x70157cf10404170EEc183043354D0a886Fa51d73);

    modifier resolveAddress {
        address proxyAddr = dosAddrBridge.getProxyAddress();
        if (address(dosProxy) != proxyAddr) {
            dosProxy = IProxy(proxyAddr);
        }
        _;
    }

    modifier auth {
        // Filter out malicious __callback__ caller.
        require(msg.sender == dosAddrBridge.getProxyAddress(), "Unauthenticated response");
        _;
    }

    // @dev: call setup function first and transfer DOS tokens into deployed contract as oracle fees.
    function DOSSetup() public onlyOwner {
        address paymentAddr = dosAddrBridge.getPaymentAddress();
        address defaultToken = IPayment(dosAddrBridge.getPaymentAddress()).defaultTokenAddr();
        IERC20(defaultToken).approve(paymentAddr, uint(-1));
        IPayment(dosAddrBridge.getPaymentAddress()).setPaymentMethod(address(this), defaultToken);
    }

    // @dev: refund all unused fees to caller.
    function DOSRefund() public onlyOwner {
        address token = IPayment(dosAddrBridge.getPaymentAddress()).defaultTokenAddr();
        uint amount = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, amount);
    }

    // @dev: Call this function to get a unique queryId to differentiate
    //       parallel requests. A return value of 0x0 stands for error and a
    //       related event would be emitted.
    // @timeout: Estimated timeout in seconds specified by caller; e.g. 15.
    //           Response is not guaranteed if processing time exceeds this.
    // @dataSource: Data source destination specified by caller.
    //              E.g.: 'https://api.coinbase.com/v2/prices/ETH-USD/spot'
    // @selector: A selector expression provided by caller to filter out
    //            specific data fields out of the raw response. The response
    //            data format (json, xml/html, and more) is identified from
    //            the selector expression.
    //            E.g. Use "$.data.amount" to extract "194.22" out.
    //             {
    //                  "data":{
    //                          "base":"ETH",
    //                          "currency":"USD",
    //                          "amount":"194.22"
    //                  }
    //             }
    //            Check below documentation for details.
    //            (https://dosnetwork.github.io/docs/#/contents/blockchains/ethereum?id=selector).
    function DOSQuery(uint timeout, string memory dataSource, string memory selector)
        internal
        resolveAddress
        returns (uint)
    {
        return dosProxy.query(address(this), timeout, dataSource, selector);
    }

    // @dev: Must override __callback__ to process a corresponding response. A
    //       user-defined event could be added to notify the Dapp frontend that
    //       the response is ready.
    // @queryId: A unique queryId returned by DOSQuery() for callers to
    //           differentiate parallel responses.
    // @result: Response for the specified queryId.
    function __callback__(uint queryId, bytes calldata result) external {
        // To be overridden in the caller contract.
    }

    // @dev: Call this function to request either a fast but insecure random
    //       number or a safe and secure random number delivered back
    //       asynchronously through the __callback__ function.
    //       Depending on the mode, the return value would be a random number
    //       (for fast mode) or a requestId (for safe mode).
    // @seed: Optional random seed provided by caller.
    function DOSRandom(uint seed)
        internal
        resolveAddress
        returns (uint)
    {
        return dosProxy.requestRandom(address(this), seed);
    }

    // @dev: Must override __callback__ to process a corresponding random
    //       number. A user-defined event could be added to notify the Dapp
    //       frontend that a new secure random number is generated.
    // @requestId: A unique requestId returned by DOSRandom() for requester to
    //             differentiate random numbers generated concurrently.
    // @generatedRandom: Generated secure random number for the specific
    //                   requestId.
    function __callback__(uint requestId, uint generatedRandom) external auth {
        // To be overridden in the caller contract.
    }
}
