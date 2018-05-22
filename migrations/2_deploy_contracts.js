"use strict";

const SimpleRegistry = artifacts.require("./SimpleRegistry.sol");
const SimpleCertifier = artifacts.require("./SimpleCertifier.sol");

module.exports = deployer => {
  deployer.deploy(SimpleRegistry);
  deployer.deploy(SimpleCertifier);
};
