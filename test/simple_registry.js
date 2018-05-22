"use strict";

const SimpleRegistry = artifacts.require("./SimpleRegistry.sol");

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

  const address = accounts[0];
  const owner = accounts[0];
  const name = "awesome";

  it("should allow reserving a new name", async () => {
    const simpleReg = await SimpleRegistry.deployed();

    const watcher = simpleReg.Reserved();

    // reservation requires a fee of 1 ETH
    await simpleReg.reserve(name, { value: web3.toWei("1", "ether") });

    // if successful the contract should emit a `Reserved` event
    const events = await watcher.get();

    assert.equal(events.length, 1);
    assert.equal(web3.toUtf8(events[0].args.name), name);
    assert.equal(events[0].args.owner, address);

    // reserved should be true
    const reserved = await simpleReg.reserved(name);
    assert.equal(reserved, true);
  });

  it("should allow name owner to set new metadata for the name", async () => {
    const simpleReg = await SimpleRegistry.deployed();

    const watcher = simpleReg.DataChanged();

    await assertThrowsAsync(
      () => simpleReg.setData(name, "A", "dummy", { from: accounts[1] }),
      "revert",
    );

    await simpleReg.setData(name, "A", "dummy");
    let events = await watcher.get();
    assert.equal(events.length, 1);
    assert.equal(web3.toUtf8(events[0].args.name), name);
    assert.equal(events[0].args.key, "A");
    assert.equal(events[0].args.plainKey, "A");

    let data = await simpleReg.getData(name, "A");
    assert.equal(web3.toUtf8(data), "dummy");

    await assertThrowsAsync(
      () => simpleReg.setAddress(name, "A", address, { from: accounts[1] }),
      "revert",
    );

    await simpleReg.setAddress(name, "A", address);
    events = await watcher.get();
    assert.equal(events.length, 1);
    assert.equal(web3.toUtf8(events[0].args.name), name);
    assert.equal(events[0].args.key, "A");
    assert.equal(events[0].args.plainKey, "A");

    data = await simpleReg.getAddress(name, "A");
    assert.equal(data, address);

    await assertThrowsAsync(
      () => simpleReg.setUint(name, "A", 100, { from: accounts[1] }),
      "revert",
    );

    await simpleReg.setUint(name, "A", 100);
    events = await watcher.get();
    assert.equal(events.length, 1);
    assert.equal(web3.toUtf8(events[0].args.name), name);
    assert.equal(events[0].args.key, "A");
    assert.equal(events[0].args.plainKey, "A");

    data = await simpleReg.getUint(name, "A");
    assert.equal(data, 100);
  });

  it("should abort reservation if name is already reserved", async () => {
    const simpleReg = await SimpleRegistry.deployed();

    const watcher = simpleReg.Reserved();

    await assertThrowsAsync(
      () => simpleReg.reserve(name, { value: web3.toWei("1", "ether") }),
      "revert",
    );

    const events = await watcher.get();
    assert.equal(events.length, 0);
  });

  it("should abort reservation if the fee is not paid", async () => {
    const simpleReg = await SimpleRegistry.deployed();

    const watcher = simpleReg.Reserved();

    await assertThrowsAsync(
      () => simpleReg.reserve("newname", { value: web3.toWei("0.5", "ether") }),
      "revert",
    );

    const events = await watcher.get();
    assert.equal(events.length, 0);
  });

  it("should allow the owner of the contract to transfer ownership", async () => {
    const simpleReg = await SimpleRegistry.deployed();
    const watcher = simpleReg.Transferred();

    // only the owner of the contract can transfer ownership
    await assertThrowsAsync(
      () => simpleReg.transfer(name, accounts[1], { from: accounts[1] }),
      "revert",
    );

    let owner = await simpleReg.getOwner(name);
    assert.equal(owner, accounts[0]);

    await simpleReg.transfer(name, accounts[1]);
    owner = await simpleReg.getOwner(name);
    assert.equal(owner, accounts[1]);

    const events = await watcher.get();
    assert.equal(events.length, 1);
    assert.equal(web3.toUtf8(events[0].args.name), name);
    assert.equal(events[0].args.oldOwner, accounts[0]);
    assert.equal(events[0].args.newOwner, accounts[1]);

    // the old owner can no longer set a new owner
    await assertThrowsAsync(
      () => simpleReg.transfer(name, accounts[0], { from: accounts[0] }),
      "revert",
    );
  });

  it("should allow the contract owner to set the registration fee", async () => {
    const simpleReg = await SimpleRegistry.deployed();

    // only the contract owner can set a new fee
    await assertThrowsAsync(
      () => simpleReg.setFee(10, { from: accounts[1] }),
      "revert",
    );

    await simpleReg.setFee(10, { from: accounts[0] });
    const fee = await simpleReg.fee();

    assert.equal(fee, 10);
  });

  it("should allow the contract owner to drop a name", async () => {
    const simpleReg = await SimpleRegistry.deployed();
    const watcher = simpleReg.Dropped();

    // only the contract owner can unregister badges
    // at this moment, `name` is transferred to `accounts[1]`
    await assertThrowsAsync(
      () => simpleReg.drop(name, { from: accounts[0] }),
      "revert",
    );

    await simpleReg.drop(name, { from: accounts[1] });

    const events = await watcher.get();
    assert.equal(events.length, 1);
    assert.equal(web3.toUtf8(events[0].args.name), name);
    assert.equal(events[0].args.owner, accounts[1]);
  });

  it("should allow the contract owner to drain all the ether from the contract", async () => {
    const simpleReg = await SimpleRegistry.deployed();

    // only the contract owner can drain the contract
    await assertThrowsAsync(
      () => simpleReg.drain({ from: accounts[1] }),
      "revert",
    );

    const balance = web3.eth.getBalance(accounts[0]);
    await simpleReg.drain({ from: accounts[0] });

    const newBalance = web3.eth.getBalance(accounts[0]);
    const expectedBalance = balance.plus(web3.toBigNumber(web3.toWei("0.99", "ether")));

    // accounts[1]'s balance should have increased by at least 0.99 ETH (to account for gas costs)
    assert(newBalance.gte(expectedBalance));
  });

  it("should not allow interactions with dropped names", async () => {
    const simpleReg = await SimpleRegistry.deployed();

    await assertThrowsAsync(
      () => simpleReg.getData(name, "A"),
      "revert",
    );

    await assertThrowsAsync(
      () => simpleReg.getAddress(name, "A"),
      "revert",
    );

    await assertThrowsAsync(
      () => simpleReg.getUint(name, "A"),
      "revert",
    );

    await assertThrowsAsync(
      () => simpleReg.getOwner(name),
      "revert",
    );

    await assertThrowsAsync(
      () => simpleReg.setData(name, "A", "dummy"),
      "revert",
    );

    await assertThrowsAsync(
      () => simpleReg.setAddress(name, "A", accounts[0]),
      "revert",
    );

    await assertThrowsAsync(
      () => simpleReg.setUint(name, "A", 100),
      "revert",
    );

    await assertThrowsAsync(
      () => simpleReg.transfer(name, accounts[1]),
      "revert",
    );

    await assertThrowsAsync(
      () => simpleReg.drop(name),
      "revert",
    );
  });
});
