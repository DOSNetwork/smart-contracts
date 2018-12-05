pragma solidity ^0.4.24;

import "truffle/Assert.sol";
import "../contracts/lib/bn256.sol";

contract TestBN256 {
    
    function testPointAdd() returns(bool) {
        BN256.G1Point memory p1 = BN256.P1();
        BN256.G1Point memory p2 = BN256.P1();           
        BN256.G1Point memory sum = BN256.pointAdd(p1, p2);
        BN256.G1Point memory p3 = BN256.scalarMul(p1,2);  
        return (sum.x == p3.x && sum.y == p3.y);
    }

    function testScarlarMul() returns(bool) {
        BN256.G1Point memory p;
        p.x = 1;  p.y = 2;
        p = BN256.scalarMul(p,2);
        return (p.x == 2 && p.y ==4);
    }

    function testPairingCheck() returns(bool) {
        BN256.G1Point[] memory g1points = new BN256.G1Point[](2);
        BN256.G2Point[] memory g2points = new BN256.G2Point[](2);
        g1points[0] = BN256.P1();
        g1points[1] = BN256.P1();
        g2points[0] = BN256.P2();
        g2points[1] = BN256.P2();
        //check e(p1[0], p2[0])  * e(p1[1], p2[1]) == 1
        if (BN256.pairingCheck(g1points,g2points) == false) {
            return false;
        }
        return true;
    }
}