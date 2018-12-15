const BN256Mock = artifacts.require("BN256Mock");
const BigNumber = require('bignumber.js');

contract("BN256 Test", async (accounts) => {
  let bn256;

  before(async () => {
    bn256 = await BN256Mock.new();
  })

  it("Test scalar multiplication", async () => {
    let p1 = await bn256.P1.call();
    let p2 = await bn256.scalarMul.call(p1, 2);
    let prod1 = await bn256.scalarMul.call(p2, 3);
    let prod2 = await bn256.scalarMul.call(p1, 6);

    assert.equal(prod1[0].toString(10), prod2[0].toString(10),
                 "After multiplication, x coordinate should equal");
    assert.equal(prod1[1].toString(10), prod2[1].toString(10),
                 "After multiplication, y coordinate should equal");
  });

  it("Test point addition", async () => {
    let p1 = await bn256.P1.call();
    let pr = await bn256.scalarMul.call(
        p1, (Math.floor(Math.random() * Number.MAX_SAFE_INTEGER) + 1) );

    let sum1 = await bn256.pointAdd.call(p1, pr);
    let sum2 = await bn256.pointAdd.call(pr, p1);


    assert.equal(sum1[0].toString(10), sum2[0].toString(10),
                 "After addition, x coordinate value equals");
    assert.equal(sum1[1].toString(10), sum2[1].toString(10),
                 "After addition, y coordinate value equals");
  });

<<<<<<< HEAD
  it("Testing pairing", async () => {
    let g1points = new Array(2);
    let g2points = new Array(2);
    g1points[0] = await bn256.P1.call();
    g1points[1] = await bn256.P1.call();
    g1points[1] = await bn256.negate.call(g1points[1]);
    g2points[0] = await bn256.P2.call();
    g2points[1] = await bn256.P2.call(); 
      
    let result = await bn256.pairingCheck.call(g1points,g2points);
    assert.equal(result,false,"check e(P1, P2)e(-P1, P2) == 0");
=======
  it("Test negate", async () => {
    let p1 = await bn256.P1.call();
    let pr = await bn256.scalarMul.call(
        p1, (Math.floor(Math.random() * Number.MAX_SAFE_INTEGER) + 1) );
    let pr_n = await bn256.negate.call(pr);
    let sum = await bn256.pointAdd.call(pr, pr_n);

    assert.equal(sum[0].toNumber(), 0, "Pr + -Pr == 0");
    assert.equal(sum[1].toNumber(), 0, "Pr + -Pr == 0");
  })

  it("Test basic pairing", async () => {
    let p1_0 = await bn256.P1.call();
    let p1_1 = await bn256.negate.call(p1_0);
    let p2 = await bn256.P2.call();
    let pass = await bn256.pairingCheck.call([p1_0, p1_1], [p2, p2]);

    assert(pass, "Basic pairing check e({p1, p2}, {-p1, p2}) should be true");
>>>>>>> f0819a2526ae58a1b2dbc829eaffed519da2c629
  });

  it("Test complex pairing check", async () => {
    // Generated secret key / public key pair.
    let SK = new BigNumber('0x250ebf796264728de1dc24d208c4cec4f813b1bcc2bb647ac8cf66206568db03');
    let PK = [
      [
        new BigNumber('0x25d7caf90ac28ba3cd8a96aff5c5bf004fc16d9bdcc2cead069e70f783397e5b'),
        new BigNumber('0x04ef63f195409b451179767b06673758e621d9db71a058231623d1cb2e594460')
      ],
      [
        new BigNumber('0x15729e3589dcb871cd46eb6774388aad867521dc07d1e0c0d9c99f444f93ca53'),
        new BigNumber('0x15db87d74b02df70d62f7f8afe5811ade35ca08bdb2308b4153624083fcf580e')
      ]
    ];

    let msg = "test random bytes";
    let hashed_msg = await bn256.hashToG1.call(msg);
    let sig = await bn256.scalarMul.call(hashed_msg, SK);
    let sig_n = await bn256.negate.call(sig);
    let G2 = await bn256.P2.call();

    let pass = await bn256.pairingCheck.call([sig_n, hashed_msg], [G2, PK]);

    assert(pass, "Pairing check e({HM, PublicKey}, {-Sig, G2}) should be true");
  })
})
