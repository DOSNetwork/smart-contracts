const BN256Mock = artifacts.require("BN256Mock");

contract("BN256 Test", async (accounts) => {
  let bn256;

  before(async () => {
    bn256 = await BN256Mock.new();
  })

  
  it("Test addition and multiply", async () => {
    let p1 = await bn256.P1.call();
    let p2 = await bn256.scalarMul.call(p1, 2);

    let sum1 = await bn256.pointAdd.call(p1, p2);
    let sum2 = await bn256.pointAdd.call(p2, p1);


    assert.equal(sum1[0].toString(10), sum2[0].toString(10), "x coordinate value equals");
    assert.equal(sum1[1].toString(10), sum2[1].toString(10), "y coordinate value equals");
  });

  it("Testing pairing", async () => {
  });
})
