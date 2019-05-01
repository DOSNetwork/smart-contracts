pragma solidity ^0.5.0;

import "./Ownable.sol";

contract ERC20I {
    function balanceOf(address who) public view returns (uint);
    function decimals() public view returns (uint);
    // function allowance(address owner, address spender) public view returns (uint);
    // function transfer(address to, uint value) public returns (bool);
    // function transferFrom(address from, address to, uint value) public returns (bool);
    // function approve(address spender, uint value) public returns (bool);
}

contract DOSPayment is Ownable {
    // DOS Token on rinkeby testnet
    address public networkToken = 0x214e79c85744CD2eBBc64dDc0047131496871bEe;
    address public droplockToken;
    uint public minStake = 50000;  // Minimum number of tokens required to be eligible into the protocol network.
    uint public droplockMaxQuota = 3;  // Each droplock quota reduces 10% of minStake requirement to participateb into protocol.
    
    event UpdateNetworkTokenAddress(address oldAddress, address newAddress);
    event UpdateDroplockTokenAddress(address oldAddress, address newAddress);
    event UpdateDroplockMaxQuota(uint oldQuota, uint newQuota);
    
    function setNetworkToken(address addr) public onlyOwner {
        emit UpdateNetworkTokenAddress(networkToken, addr);
        networkToken = addr;
    }
    
    function setDroplockToken(address addr) public onlyOwner {
        emit UpdateDroplockTokenAddress(droplockToken, addr);
        droplockToken = addr;
    }

    function setDroplockMaxQuota(uint quo) public onlyOwner {
        require(quo != droplockMaxQuota && quo < 10, "Valid droplockMaxQuota within 0 to 9");
        
        emit UpdateDroplockMaxQuota(droplockMaxQuota, quo);
        droplockMaxQuota = quo;
    }

    // TODO: Rewrite eligibility and staking algorithm.
    function fromValidStakingNode(address node) public view returns(bool) {
        uint networkTokenBalance = ERC20I(networkToken).balanceOf(node);
        uint networkTokenDecimals = ERC20I(networkToken).decimals();
        if (networkTokenBalance >= minStake * networkTokenDecimals) {
            return true;
        } else if (droplockToken == address(0x0)) {
            return false;
        } else {
            uint droplockTokenNum = ERC20I(droplockToken).balanceOf(node) / ERC20I(droplockToken).decimals();
            if (droplockTokenNum > droplockMaxQuota) {
                droplockTokenNum = droplockMaxQuota;
            }
            return networkTokenBalance >= minStake * networkTokenDecimals * (10 - droplockTokenNum) / 10;
        }
    }
    
    // TODO: Implement delegate stake, staking incentive, withdraw incentive algorithms.

}
