const BN256 = artifacts.require('./TestBN256.sol');

  contract('BN256', function() {

      it('should return true for point add', function() {
        return BN256.deployed().then(function(instance) {
            return instance.testPointAddAndScalarMul.call();
        }).then(function(result) {
            assert.equal(result, true, "point add fail");
        });        
      });

      it('should return true for pairingCheck', function() {
        return BN256.deployed().then(function(instance) {
            return instance.testPairingCheck.call();
         }).then(function(result){
            assert.equal(result, true, "pairingCheck fail");
         })
    });
  })