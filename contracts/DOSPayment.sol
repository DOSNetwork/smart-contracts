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
    // DropBurn Token on rinkeby testnet
    address public dropburnToken = 0x9bfE8F5749d90eB4049Ad94CC4De9b6C4C31f822;
    uint public minStake = 50000;  // Minimum number of tokens required to be eligible into the protocol network.
    uint public dropburnMaxQuota = 3;  // Each DropBurn quota reduces 10% of minStake requirement to participate into protocol.
    
    event UpdateNetworkTokenAddress(address oldAddress, address newAddress);
    event UpdateDropBurnTokenAddress(address oldAddress, address newAddress);
    event UpdateDropBurnMaxQuota(uint oldQuota, uint newQuota);
    
    function setNetworkToken(address addr) public onlyOwner {
        emit UpdateNetworkTokenAddress(networkToken, addr);
        networkToken = addr;
    }
    
    function setDropBurnToken(address addr) public onlyOwner {
        emit UpdateDropBurnTokenAddress(dropburnToken, addr);
        dropburnToken = addr;
    }

    function setDropBurnMaxQuota(uint quo) public onlyOwner {
        require(quo != dropburnMaxQuota && quo < 10, "Valid dropburnMaxQuota within 0 to 9");
        
        emit UpdateDropBurnMaxQuota(dropburnMaxQuota, quo);
        dropburnMaxQuota = quo;
    }

    // TODO: Rewrite eligibility and staking algorithm.
    function fromValidStakingNode(address node) public view returns(bool) {
        uint networkTokenBalance = ERC20I(networkToken).balanceOf(node);
        uint networkTokenDecimals = ERC20I(networkToken).decimals();
        uint minNetworkStakingBalance = minStake * (10 ** networkTokenDecimals);
        if (networkTokenBalance >= minNetworkStakingBalance) {
            return true;
        } else if (dropburnToken == address(0x0)) {
            return false;
        } else {
            uint dropburnTokenNum = ERC20I(dropburnToken).balanceOf(node) / (10 ** ERC20I(dropburnToken).decimals());
            if (dropburnTokenNum > dropburnMaxQuota) {
                dropburnTokenNum = dropburnMaxQuota;
            }
            return networkTokenBalance >= minNetworkStakingBalance * (10 - dropburnTokenNum) / 10;
        }
    }
    
    // TODO: Implement delegate stake, staking incentive, withdraw incentive algorithms.

}
