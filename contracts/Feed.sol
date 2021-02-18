pragma solidity ^0.5.0;

contract FeedProxy {
    
}


library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting with custom message on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, errorMessage);

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction underflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, errorMessage);

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts with custom message on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

import "./DOSOnChainSDK.sol";

contract Feed is DOSOnChainSDK {
    using SafeMath for uint;

    uint public constant ONEHOUR = 1 hours;
    uint public constant ONEDAY = 1 days;
    uint private UINT_MAX = uint(-1);  // overflow flag
    uint public windowSize = 1200;     // 20 minutes
    
    struct Observation {
        uint timestamp;
        uint price;
    }
    
    string private source;
    string private selector;
    // Reader whitelist
    mapping(address => bool) private whitelist;
    Observation[] private observations;
    
    event QueryUpdated(string oldSource, string newSource, string oldSelector, string newSelector);
    event WindowUpdated(uint oldWindow, uint newWindow);
    event AddAccess(address reader);
    event RemoveAccess(address reader);
    
    modifier accessible {
        require(whitelist[msg.sender] || msg.sender == tx.origin, "not-accessible");
        _;
    }
    
    constructor(string memory _source, string memory _selector) public {
        // @dev: setup and then transfer DOS tokens into deployed contract
        // as oracle fees.
        // Unused fees can be reclaimed by calling DOSRefund() function of SDK contract.
        super.DOSSetup();
        source = _source;
        selector = _selector;
        emit QueryUpdated('', _source, '', _selector);
    }
    
    function updateQuery(string memory _source, string memory _selector) public onlyOwner {
        emit QueryUpdated(source, _source, selector, _selector);
        source = _source;
        selector = _selector;
    }
    // This will erase all observed data!
    function updateWindowSize(uint newWindow) public onlyOwner {
        emit WindowUpdated(windowSize, newWindow);
        windowSize = newWindow;
        delete observations;
    }
    function addToList(address reader) public onlyOwner {
        if (!whitelist[reader]) {
            whitelist[reader] = true;
            emit AddAccess(reader);
        }
    }
    function removeFromList(address reader) public onlyOwner {
        if (whitelist[reader]) {
            delete whitelist[reader];
            emit RemoveAccess(reader);
        }
    }
    
    function __callback__(uint id, bytes calldata result) external auth {
        // update();
    }
    
    function update(uint price) private returns (bool) {
        uint lastTime = observations.length > 0 ? observations[observations.length - 1].timestamp : 0;
        uint timeElapsed = block.timestamp.sub(lastTime);
//        uint delta = 
        if (timeElapsed >= windowSize) {
            observations.push(Observation(block.timestamp, price));
            return true;
        }
        return false;
    }
    
    // Return latest reported price & timestamp data.
    function latestResult() public view accessible returns (uint _lastPrice, uint _lastUpdatedTime) {
        require(observations.length > 0);
        Observation storage last = observations[observations.length - 1];
        return (last.price, last.timestamp);
    }
    
    // Given sample size return time-weighted average price (TWAP) between (observations[start] : observations[end])
    function twapResult(uint start) public view accessible returns (uint) {
        require(start < observations.length, "index-overflow");
        
        uint end = observations.length - 1;
        uint cumulativePrice = 0;
        for (uint i = start; i < end; i++) {
            cumulativePrice = cumulativePrice.add(observations[i].price.mul(observations[i+1].timestamp.sub(observations[i].timestamp)));
        }
        uint timeElapsed = observations[end].timestamp.sub(observations[start].timestamp);
        return cumulativePrice.div(timeElapsed);
    }
    
    // Observation[] is sorted by timestamp in ascending order. Return the maximum index {i}, satisfying that: observations[i].timestamp <= observations[end].timestamp.sub(timedelta)
    // Return UINT_MAX if not enough data points.
    function binarySearch(uint timedelta) public view returns (uint) {
        int index = -1;
        int l = 0;
        int r = int(observations.length.sub(1));
        uint key = observations[uint(r)].timestamp.sub(timedelta);
        while (l <= r) {
            int m = (l + r) / 2;
            uint m_val = observations[uint(m)].timestamp;
            if (m_val <= key) {
                index = m;
                l = m + 1;
            } else {
                r = m - 1;
            }
        }
        return uint(index);
    }
    
    function TWAP1Hour() public view accessible returns (uint) {
        // require();
        uint idx = binarySearch(ONEHOUR);
        require(idx != UINT_MAX, "not-enough-observation-data-for-1h");
        return twapResult(idx);
    }
    
    function TWAP2Hour() public view accessible returns (uint) {
        // require();
        uint idx = binarySearch(ONEHOUR * 2);
        require(idx != UINT_MAX, "not-enough-observation-data-for-2h");
        return twapResult(idx);
    }
    
    function TWAP4Hour() public view accessible returns (uint) {
        // require();
        uint idx = binarySearch(ONEHOUR * 4);
        require(idx != UINT_MAX, "not-enough-observation-data-for-4h");
        return twapResult(idx);
    }

    function TWAP6Hour() public view accessible returns (uint) {
        // require();
        uint idx = binarySearch(ONEHOUR * 6);
        require(idx != UINT_MAX, "not-enough-observation-data-for-6h");
        return twapResult(idx);
    }

    function averageResult8Hour() public view accessible returns (uint) {
        // require();
        uint idx = binarySearch(ONEHOUR * 8);
        require(idx != UINT_MAX, "not-enough-observation-data-for-8h");
        return twapResult(idx);
    }
    
    function TWAP12Hour() public view accessible returns (uint) {
        // require();
        uint idx = binarySearch(ONEHOUR * 12);
        require(idx != UINT_MAX, "not-enough-observation-data-for-12h");
        return twapResult(idx);
    }
    
    function TWAP1Day() public view accessible returns (uint) {
        // require();
        uint idx = binarySearch(ONEDAY);
        require(idx != UINT_MAX, "not-enough-observation-data-for-1d");
        return twapResult(idx);
    }
    
    function TWAP1Week() public view accessible returns (uint) {
        // require();
        uint idx = binarySearch(ONEDAY * 7);
        require(idx != UINT_MAX, "not-enough-observation-data-for-1week");
        return twapResult(idx);
    }
}
