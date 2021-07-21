const { expect } = require("chai");
const { assert } = require("hardhat");
const NetSepio = artifacts.require("NetSepio");
const {BN, constants, expectEvent, expectRevert} = require('@openzeppelin/test-helpers');

let accounts;
let netSepio;
let owner;
let consumer;
let stranger;

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("NetSepio Contract", function () {

  before(async function() {
    accounts = await web3.eth.getAccounts();
    owner       = accounts[0];
    consumer    = accounts[1];
    stranger    = accounts[2];
    netSepio = await NetSepio.new("NetSepio", "NETSEC", "https://localhost:3000/artifacts/");
  });
  
  // TODO: Perform complete coverage tests
  describe("NetSepio deployment", function() {
    it("Should return the right name and symbol of the token once NetSepio is deployed", async function() {
      assert.equal(await netSepio.name(), "NetSepio");
      assert.equal(await netSepio.symbol(), "NETSEC");
    });
  });
});
