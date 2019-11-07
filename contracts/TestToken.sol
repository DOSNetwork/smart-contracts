pragma solidity >=0.5.0 <0.6.0;

contract TestToken {

    string public constant name = "TestToken";
    string public constant symbol = "TTK";
    uint8 public constant decimals = 18;  
    uint256 private constant MAX_SUPPLY = 1e9 * 1e18; // 1 billion total supply
    uint256 private _supply = MAX_SUPPLY;

    event Approval(address indexed tokenOwner, address indexed spender, uint wad);
    event Transfer(address indexed from, address indexed to, uint wad);


    mapping(address => uint256) balances;

    mapping(address => mapping (address => uint256)) allowed;
    
    using SafeMath for uint256;


   constructor() public {  
	balances[msg.sender] = _supply;
    }  

    function totalSupply() public view returns (uint256) {
	return _supply;
    }
    
    function balanceOf(address tokenOwner) public view returns (uint) {
        return balances[tokenOwner];
    }

    function transfer(address receiver, uint wad) public returns (bool) {
        require(wad <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(wad);
        balances[receiver] = balances[receiver].add(wad);
        emit Transfer(msg.sender, receiver, wad);
        return true;
    }

    function approve(address delegate, uint wad) public returns (bool) {
        allowed[msg.sender][delegate] = wad;
        emit Approval(msg.sender, delegate, wad);
        return true;
    }

    function allowance(address owner, address delegate) public view returns (uint) {
        return allowed[owner][delegate];
    }

    function transferFrom(address owner, address buyer, uint wad) public returns (bool) {
        require(wad <= balances[owner]);
        require(wad <= allowed[owner][msg.sender]);
        if (owner != msg.sender && allowed[owner][msg.sender] != uint(-1)) {
            require(allowed[owner][msg.sender] >= wad, "token-insufficient-approval");
            allowed[owner][msg.sender] = allowed[owner][msg.sender].sub(wad);
        }
        balances[owner] = balances[owner].sub(wad);
        balances[buyer] = balances[buyer].add(wad);
        emit Transfer(owner, buyer, wad);
        return true;
    }
}

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
}