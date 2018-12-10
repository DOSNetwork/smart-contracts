pragma solidity >= 0.4.24;
 import "./lib/BN256.sol";
 
contract BN256Mock {
    uint public flag = 0;
    function P1() public pure returns (uint[2] memory) {
        return [ BN256.P1().x, BN256.P1().y ];
    }
     function P2() public pure returns (uint[2][2] memory) {
        return [
            [BN256.P2().x[0], BN256.P2().x[1]],
            [BN256.P2().y[0], BN256.P2().y[1]]
        ];
    }   
    function negate(uint[2] memory p) public returns(uint[2] memory) {
        return [ BN256.negate(BN256.G1Point(p[0],p[1])).x, BN256.negate(BN256.G1Point(p[0],p[1])).y];
    }
     function pointAdd(uint[2] memory p1, uint[2] memory p2)
        public
        returns (uint[2] memory)
    {
        BN256.G1Point memory sum = BN256.pointAdd(BN256.G1Point(p1[0], p1[1]),
                                                  BN256.G1Point(p2[0], p2[1]));
        return [sum.x, sum.y];
    }
     function scalarMul(uint[2] memory p1, uint s)
        public
        returns (uint[2] memory) 
    {
        BN256.G1Point memory prod =
            BN256.scalarMul(BN256.G1Point(p1[0], p1[1]), s);
        return [prod.x, prod.y];
    }
     function pairingCheck(uint[2][] memory p1, uint[2][2][] memory p2)
        public
    {
        require(p1.length == p2.length);
         BN256.G1Point[] memory b_p1 = new BN256.G1Point[](p1.length);
        BN256.G2Point[] memory b_p2 = new BN256.G2Point[](p1.length);
        for (uint i = 0; i < p1.length; i++) {
            b_p1[i] = BN256.G1Point(p1[i][0], p1[1][1]);
            b_p2[i] = BN256.G2Point([p2[i][0][0], p2[i][0][1]],
                                    [p2[i][1][0], p2[i][1][1]]);
        }
        require(BN256.pairingCheck(b_p1, b_p2) == false);
        flag = 1;
    }
 }