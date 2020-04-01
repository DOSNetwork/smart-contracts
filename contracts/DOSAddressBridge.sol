pragma solidity ^0.5.0;

import "./Ownable.sol";

contract DOSAddressBridge is Ownable {
    // Deployed DOSProxy contract address.
    address private _proxyAddress;
    // Deployed CommitReveal contract address.
    address private _commitrevealAddress;
    // Deployed DOSPayment contract address.
    address private _paymentAddress;
    // Deployed StakingGateway contract address.
    address private _stakingAddress;
    // BootStrap node lists.
    string private _bootStrapUrl;

    event ProxyAddressUpdated(address previousProxy, address newProxy);
    event CommitRevealAddressUpdated(address previousAddr, address newAddr);
    event PaymentAddressUpdated(address previousPayment, address newPayment);
    event StakingAddressUpdated(address previousStaking, address newStaking);
    event BootStrapUrlUpdated(string previousURL, string newURL);

    function getProxyAddress() public view returns (address) {
        return _proxyAddress;
    }

    function setProxyAddress(address newAddr) public onlyOwner {
        emit ProxyAddressUpdated(_proxyAddress, newAddr);
        _proxyAddress = newAddr;
    }

    function getCommitRevealAddress() public view returns (address) {
        return _commitrevealAddress;
    }

    function setCommitRevealAddress(address newAddr) public onlyOwner {
        emit CommitRevealAddressUpdated(_commitrevealAddress, newAddr);
        _commitrevealAddress = newAddr;
    }

    function getPaymentAddress() public view returns (address) {
        return _paymentAddress;
    }

    function setPaymentAddress(address newAddr) public onlyOwner {
        emit PaymentAddressUpdated(_paymentAddress, newAddr);
        _paymentAddress = newAddr;
    }

    function getStakingAddress() public view returns (address) {
        return _stakingAddress;
    }

    function setStakingAddress(address newAddr) public onlyOwner {
        emit StakingAddressUpdated(_stakingAddress, newAddr);
        _stakingAddress = newAddr;
    }

    function getBootStrapUrl() public view returns (string memory) {
        return _bootStrapUrl;
    }

    function setBootStrapUrl(string memory url) public onlyOwner {
        emit BootStrapUrlUpdated(_bootStrapUrl, url);
        _bootStrapUrl = url;
    }
}
