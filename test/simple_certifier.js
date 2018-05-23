"use strict";

const SimpleCertifier = artifacts.require("./SimpleCertifier.sol");

contract("SimpleRegistry", accounts => {
  const assertThrowsAsync = async (fn, msg) => {
    try {
      await fn();
    } catch (err) {
      assert(err.message.includes(msg), "Expected error to include: " + msg);
      return;
    }
    assert.fail("Expected fn to throw");
  };

   it("should allow certify an address", async () => {
     const cert = await SimpleCertifier.deployed();

     assertThrowsAsync(
       () => cert.setDelegate(accounts[0], { from: accounts[1] }),
       "revert"
     );

     await cert.setDelegate(accounts[0]);
     assert.equal(await cert.certified(accounts[1]), false);

     await cert.certify(accounts[1]);
     assert.equal(await cert.certified(accounts[1]), true);

     assertThrowsAsync(
       () => cert.revoke(accounts[1], { from: accounts[1] }),
       "revert"
     );

     await cert.revoke(accounts[1]);
     assert.equal(await cert.certified(accounts[1]), false);

     assertThrowsAsync(
       () => cert.revoke(accounts[1]),
       "revert"
     );
   });
});
