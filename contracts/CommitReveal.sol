pragma solidity ^0.5.0;

import "./Ownable.sol";

contract CommitReveal is Ownable {
    struct Participant {
        uint secret;
        bytes32 commitment;
        bool revealed;
    }
    
    struct Campaign {
        uint startBlock;
        uint commitDuration;  // in blocks
        uint revealDuration;  // in blocks
        uint revealThreshold;
        uint commitNum;
        uint revealNum;
        uint generatedRandom;
        mapping(address => Participant) participants;
        mapping(bytes32 => bool) commitments;
    }

    Campaign[] public campaigns;
    // Only whitelised contracts are permitted to kick off commit-reveal process
    mapping(address => bool) public whitelisted;

    modifier checkCommit(uint _cid, bytes32 _commitment) {
        Campaign storage c = campaigns[_cid];
        require(_cid != 0 &&
                block.number >= c.startBlock &&
                block.number < c.startBlock + c.commitDuration,
                "Not in commit phase");
        require(_commitment != "", "Empty commitment");
        require(!c.commitments[_commitment], "Duplicated commitment");
        _;
    }
    modifier checkReveal(uint _cid) {
        Campaign storage c = campaigns[_cid];
        require(_cid != 0 &&
                block.number >= c.startBlock + c.commitDuration &&
                block.number < c.startBlock + c.commitDuration + c.revealDuration,
                "Not in reveal phase");
        _;
    }
    modifier checkFinish(uint _cid) {
        Campaign storage c = campaigns[_cid];
        require(_cid != 0 &&
                block.number >= c.startBlock + c.commitDuration + c.revealDuration,
                "Commit Reveal not finished yet");
        _;
    }
    modifier onlyWhitelisted {
        require(whitelisted[msg.sender], "Not whitelisted!");
        _;
    }
    
    event LogStartCommitReveal(uint cid, uint startBlock, uint commitDuration, uint revealDuration, uint revealThreshold);
    event LogCommit(uint cid, address from, bytes32 commitment);
    event LogReveal(uint cid, address from, uint secret);
    event LogRandom(uint cid, uint random);

    constructor() public {
        // campaigns[0] is not used.
        campaigns.length++;
    }

    function addToWhitelist(address _addr) public onlyOwner {
        whitelisted[_addr] = true;
    }
    function removeFromWhitelist(address _addr) public onlyOwner {
        delete whitelisted[_addr];
    }

    // Returns new campaignId.
    function startCommitReveal(
        uint _startBlock,
        uint _commitDuration,
        uint _revealDuration,
        uint _revealThreshold
    )
        public
        onlyWhitelisted
        returns(uint)
    {
        uint newCid = campaigns.length;
        campaigns.push(Campaign(_startBlock, _commitDuration, _revealDuration, _revealThreshold, 0, 0, 0));
        emit LogStartCommitReveal(newCid, _startBlock, _commitDuration, _revealDuration, _revealThreshold);
        return newCid;
    }

    function commit(uint _cid, bytes32 _secretHash) public checkCommit(_cid, _secretHash) {
        Campaign storage c = campaigns[_cid];
        c.commitments[_secretHash] = true;
        c.participants[msg.sender] = Participant(0, _secretHash, false);
        c.commitNum++;
        emit LogCommit(_cid, msg.sender, _secretHash);
    }

    function reveal(uint _cid, uint _secret) public checkReveal(_cid) {
        Campaign storage c = campaigns[_cid];
        Participant storage p = c.participants[msg.sender];
        require(!p.revealed && keccak256(abi.encodePacked(_secret)) == p.commitment,
                "Revealed secret doesn't match with commitment");
        p.secret = _secret;
        p.revealed = true;
        c.revealNum++;
        c.generatedRandom ^= _secret;
        emit LogReveal(_cid, msg.sender, _secret);
    }

    // Return value of 0 representing invalid random output.
    function getRandom(uint _cid) public view checkFinish(_cid) returns (uint) {
        Campaign storage c = campaigns[_cid];
        if (c.revealNum >= c.revealThreshold) {
            return c.generatedRandom;
        } else{
            return 0;
        }
    }
}
