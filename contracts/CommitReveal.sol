pragma solidity ^0.5.0;

contract CommitReveal {
    
    constructor() public {
    }
    
    struct Participant {
        uint   secret;
        bytes32   commitment;
        bool      revealed;
    }

    uint    targetBlkNum;
    uint    commitDuration;
    uint    revealDuration;
    uint   random;
    bool      settled;
    uint    commitNum;
    uint    revealsNum;

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
        uint _revealDuration
    ) timeLineCheck(_targetBlkNum, _commitDuration, _revealDuration)
    public {
        targetBlkNum = _targetBlkNum;
        commitDuration = _commitDuration;
        revealDuration = _revealDuration;
        emit LogStartCommitReveal(targetBlkNum, commitDuration, revealDuration);
    }

    function commit(
        bytes32 _secretHash
    ) notBeBlank(_secretHash) 
      checkCommitPhase(targetBlkNum, commitDuration, revealDuration) 
    public {
       if (commitments[_secretHash]) {
            revert();
        } else {
            participants[msg.sender] = Participant(0, _secretHash, false);
            commitNum++;
            commitments[_secretHash] = true;
            emit LogCommit( msg.sender, _secretHash);
        }
    }

    function reveal(
        uint _secret
    ) checkRevealPhase(targetBlkNum, revealDuration)
    public {
        Participant storage p = participants[msg.sender];
        if (p.revealed) revert();
        if (keccak256(abi.encodePacked(_secret)) != p.commitment) revert();
        p.secret = _secret;
        p.revealed = true;
        revealsNum++;
        random = uint(keccak256(abi.encodePacked(random, _secret)));
        delete commitments[p.commitment];
        delete participants[msg.sender];
        emit LogReveal(msg.sender, _secret);
    }

    function getRandom() finishPhase(targetBlkNum) public returns (uint) {
        if (revealsNum == commitNum) {
            emit LogRandom(random);
            return random;
        }else{
            revert();
        }
    }
}
