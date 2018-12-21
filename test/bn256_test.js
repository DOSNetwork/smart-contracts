const BN256Mock = artifacts.require("BN256Mock");
const BN = require('bn.js');

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
  });

  it("Test complex pairing check", async () => {
    // Generated secret key / public key pair.
    let SK = new BN('3');
    let PK = [
        new BN('7273165102799931111715871471550377909735733521218303035754523677688038059653'),
        new BN('2725019753478801796453339367788033689375851816420509565303521482350756874229'),
        new BN('957874124722006818841961785324909313781880061366718538693995380805373202866'),
        new BN('2512659008974376214222774206987427162027254181373325676825515531566330959255')
        ];

    let str = "Hello Boneh-Lynn-Shacham";
    let bytes = [];
    for (var i = 0; i < str.length; ++i) {
        var code = str.charCodeAt(i);
        bytes = bytes.concat([code]);
    }
    let hashed_msg = await bn256.hashToG1.call(bytes);
    let sig = await bn256.scalarMul.call(hashed_msg, SK);
    let sig_n = await bn256.negate.call(sig);
    let G2 = await bn256.P2.call();
    let pass = await bn256.pairingCheck.call([sig_n, hashed_msg], [G2, PK]);
    assert(pass, "Pairing check e({HM, PublicKey}, {-Sig, G2}) should be true");

  })
})
