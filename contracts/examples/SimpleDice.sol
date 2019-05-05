pragma solidity ^0.5.0;

//import "github.com/DOSNetwork/eth-contracts/contracts/DOSOnChainSDK.sol";
import "../DOSOnChainSDK.sol";

contract SimpleDice is DOSOnChainSDK {
    address payable public devAddress = 0xe4E18A49c6F1210FFE9a60dBD38071c6ef78d982;
    uint public devContributed = 0;
    // 1% winning payout goes to developer account
    uint public developCut = 1;
    // precise to 4 digits after decimal point.
    uint public decimal = 4;
    // gameId => gameInfo
    mapping(uint => DiceInfo) public games;

    struct DiceInfo {
        uint rollUnder;  // betted number, player wins if random < rollUnder
        uint amountBet;  // amount in wei
        address payable player;  // better address
    }

    event ReceivedBet(
        uint gameId,
        uint rollUnder,
        uint weiBetted,
        address better
    );
    event PlayerWin(uint gameId, uint generated, uint betted, uint amountWin);
    event PlayerLose(uint gameId, uint generated, uint betted);

    modifier auth {
        // Filter out malicious __callback__ callers.
        require(msg.sender == fromDOSProxyContract(), "Unauthenticated response");
        _;
    }

    modifier onlyDev {
        require(msg.sender == devAddress);
        _;
    }

    function min(uint a, uint b) internal pure returns(uint) {
        return a < b ? a : b;
    }
    // Only receive bankroll funding from developer.
    function() external payable onlyDev {
        devContributed += msg.value;
    }
    // Only developer can withdraw the amount up to what he has contributed.
    function devWithdrawal() public onlyDev {
        uint withdrawalAmount = min(address(this).balance, devContributed);
        devContributed = 0;
        devAddress.transfer(withdrawalAmount);
    }

    // 100 / (rollUnder - 1) * (1 - 0.01) => 99 / (rollUnder - 1)
    // Not using SafeMath as this function cannot overflow anyway.
    function computeWinPayout(uint rollUnder) public view returns(uint) {
        return 99 * (10 ** decimal) / (rollUnder - 1);
    }

    // 100 / (rollUnder - 1) * 0.01
    function computeDeveloperCut(uint rollUnder) public view returns(uint) {
        return 10 ** decimal / (rollUnder - 1);
    }

    function play(uint rollUnder) public payable {
        // winChance within [1%, 95%]
        require(rollUnder >= 2 && rollUnder <= 96, "rollUnder should be in 2~96");
        // Make sure contract has enough balance to cover payouts before game.
        // Not using SafeMath as I'm not expecting this demo contract's
        // balance to be very large.
        require(address(this).balance * (10 ** decimal) >= msg.value * computeWinPayout(rollUnder),
                "Game contract doesn't have enough balance, decrease rollUnder");

        // Request a safe, unmanipulatable random number from DOS Network with
        // optional seed.
        uint gameId = DOSRandom(1, now);

        games[gameId] = DiceInfo(rollUnder, msg.value, msg.sender);
        // Emit event to notify Dapp frontend
        emit ReceivedBet(gameId, rollUnder, msg.value, msg.sender);
    }

    function __callback__(uint requestId, uint generatedRandom) external auth {
        address payable player = games[requestId].player;
        require(player != address(0x0));

        uint gen_rnd = generatedRandom % 100 + 1;
        uint rollUnder = games[requestId].rollUnder;
        uint betted = games[requestId].amountBet;
        delete games[requestId];

        if (gen_rnd < rollUnder) {
            // Player wins
            uint payout = betted * computeWinPayout(rollUnder) / (10 ** decimal);
            uint devPayout = betted * computeDeveloperCut(rollUnder) / (10 ** decimal);

            emit PlayerWin(requestId, gen_rnd, rollUnder, payout);
            player.transfer(payout);
            devAddress.transfer(devPayout);
        } else {
            // Lose
            emit PlayerLose(requestId, gen_rnd, rollUnder);
        }
    }
}
