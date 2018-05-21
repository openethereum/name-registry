"use strict";

const SimpleRegistry = artifacts.require("./SimpleRegistry.sol");

module.exports = deployer => {
  deployer.deploy(SimpleRegistry);
};
