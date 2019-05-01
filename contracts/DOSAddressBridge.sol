pragma solidity ^0.5.0;

import "./Ownable.sol";

contract DOSAddressBridge is Ownable {
    // Deployed DOSProxy contract address.
    address private _proxyAddress;
    // Deployed CommitReveal contract address.
    address private _commitrevealAddress;
    // Deployed DOSPayment contract address.
    address private _paymentAddress;
    // Deployed DOSRegistry contract address.
    address private _registryAddress;

    event ProxyAddressUpdated(address previousProxy, address newProxy);
    event CommitRevealAddressUpdated(address previousAddr, address newAddr);
    event PaymentAddressUpdated(address previousPayment, address newPayment);
    event RegistryAddressUpdated(address previousRegistry, address newRegistry);

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

    function getRegistryAddress() public view returns (address) {
        return _registryAddress;
    }

    function setRegistryAddress(address newAddr) public onlyOwner {
        emit RegistryAddressUpdated(_registryAddress, newAddr);
        _registryAddress = newAddr;
    }
}
