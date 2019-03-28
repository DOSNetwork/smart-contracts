pragma solidity ^0.5.0;

import "./Ownable.sol";

contract DOSAddressBridge is Ownable {
    // Deployed DOSProxy contract address.
    address private _proxyAddress;
    // Deployed DOSPayment contract address.
    address private _paymentAddress;
    // Deployed DOSRegistry contract address.
    address private _registryAddress;
    // Deployed CommitReveal contract address.
    address private _commitrevealAddress;

    event ProxyAddressUpdated(address previousProxy, address newProxy);
    event PaymentAddressUpdated(address previousPayment, address newPayment);
    event RegistryAddressUpdated(address previousRegistry, address newRegistry);
    event RegistryCommitRevealUpdated(address previousCommitReveal, address newCommitReveal);

    function getProxyAddress() public view returns (address) {
        return _proxyAddress;
    }

    function setProxyAddress(address newAddr) public onlyOwner {
        emit ProxyAddressUpdated(_proxyAddress, newAddr);
        _proxyAddress = newAddr;
    }

    function getPaymentAddress() public view returns (address) {
        return _paymentAddress;
    }

    function setPaymentAddress(address newAddr) public onlyOwner {
        emit PaymentAddressUpdated(_paymentAddress, newAddr);
        _paymentAddress = newAddr;
    }

    function getRegistryAddress() public view returns (address) {
        return _registryAddress;
    }

    function setRegistryAddress(address newAddr) public onlyOwner {
        emit RegistryAddressUpdated(_registryAddress, newAddr);
        _registryAddress = newAddr;
    }

    function getCommitRevealAddress() public view returns (address) {
        return _commitrevealAddress;
    }

    function setCommitRevealAddress(address newAddr) public onlyOwner {
        emit ProxyAddressUpdated(_commitrevealAddress, newAddr);
        _commitrevealAddress = newAddr;
    }
}
