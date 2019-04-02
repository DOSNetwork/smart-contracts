pragma solidity ^0.5.0;

contract DOSAddressBridgeInterface {
    function getProxyAddress() public view returns (address);
}

contract DOSCommitReveal {
    
    constructor() public {
    }
    
    struct Participant {
        uint   secret;
        bytes32   commitment;
        bool      revealed;
    }
    
    DOSAddressBridgeInterface dosAddrBridge =
        DOSAddressBridgeInterface(0xE6DEAae3d9A42cc602f3F81E669245386162b68A);
        
    uint    targetBlkNum;
    uint    commitDuration;
    uint    revealDuration;
    uint    random;
    bool    settled;
    uint    commitNum;
    uint    revealsNum;
    uint    revealThreshold;
    address[] public revealer;
    mapping (address => Participant) participants;
    
    mapping (bytes32 => bool) commitments;


    modifier blankAddress(address n) {if (n != address(0)) revert(); _;}

    modifier notBeBlank(bytes32 _s) {if (_s == "") revert(); _;}

    modifier beBlank(bytes32 _s) {if (_s != "") revert(); _;}

    modifier beFalse(bool _t) {if (_t) revert(); _;}
    
    modifier timeLineCheck(uint _targetBlkNum, uint _commitDuration, uint _revealDuration) {
        if (block.number >= _targetBlkNum) revert();
        if (_commitDuration <= 0) revert();
        if (_revealDuration <= 0) revert();
        if (block.number >= (_targetBlkNum - _revealDuration - _commitDuration)) revert();
        _;
    }
    modifier thresholdCheck(uint _revealThreshold) {
        if (_revealThreshold <= 0) revert();
        _;
    }

    modifier checkCommitPhase(uint _targetBlkNum, uint _commitDuration, uint _revealDuration) {
        if (block.number < (_targetBlkNum - _revealDuration - _commitDuration)) revert();
        if (block.number > (_targetBlkNum - _revealDuration)) revert();
        _;
    }
    modifier checkRevealPhase(uint _targetBlkNum, uint _revealDuration) {
        if (block.number <= (_targetBlkNum - _revealDuration)) revert();
        if (block.number >= _targetBlkNum) revert();
        _;
    }
    
    modifier finishPhase(uint _targetBlkNum){if (block.number < targetBlkNum) revert(); _;}
    
    modifier onlyWhitelisted {
        require(dosAddrBridge.getProxyAddress() == msg.sender, "Not whitelisted!");
        _;
    }
    
    //|-commitDuration-|-revealDuration-|(targetBlkNum)
    event LogStartCommitReveal( uint targetBlkNum,
                            uint commitDuration,
                            uint revealDuration);
    event LogCommit(address from, bytes32 commitment);
    event LogReveal(address from, uint secret);
    event LogRandom(uint random);

    function startCommitReveal(
        uint _targetBlkNum,
        uint _commitDuration,
        uint _revealDuration,
        uint _revealThreshold
    ) timeLineCheck(_targetBlkNum, _commitDuration, _revealDuration)
      thresholdCheck(_revealThreshold) public onlyWhitelisted{
        targetBlkNum = _targetBlkNum;
        commitDuration = _commitDuration;
        revealDuration = _revealDuration;
        revealThreshold = _revealThreshold;
        random = 0;
        emit LogStartCommitReveal(targetBlkNum, commitDuration, revealDuration);
    }

    function commit(
        bytes32 _secretHash
    ) notBeBlank(_secretHash) 
      checkCommitPhase(targetBlkNum, commitDuration, revealDuration) 
    public {
        participants[msg.sender] = Participant(0, _secretHash, false);
        emit LogCommit( msg.sender, _secretHash);
    }

    function reveal(
        uint _secret
    ) checkRevealPhase(targetBlkNum, revealDuration)
    public {
        Participant storage p = participants[msg.sender];
        if (p.revealed) revert();
        if (keccak256(abi.encodePacked(_secret)) != p.commitment) revert();
        revealer.push(msg.sender);
        p.secret = _secret;
        p.revealed = true;
    }

    function getRandom() finishPhase(targetBlkNum) public returns (uint) {
        if (random == 0) {
            if (revealer.length < revealThreshold){
                revert();
            }else{
                for (uint i = 0; i < revealer.length; i++) {
                    Participant storage p = participants[revealer[i]];
                    random = uint(keccak256(abi.encodePacked(random, p.secret)));
	            delete participants[revealer[i]];
                    emit LogReveal(msg.sender, p.secret);
                }
                revealer.length =0;
                return random;
            }
        }else{
            return random;
        }
    }
}

