const { expect } = require("chai");
const { assert } = require("hardhat");
const NetSepio = artifacts.require("NetSepio");
const {
  BN,           // Big Number support
  constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

let accounts;
let netSepio;
let owner;
let nonOwner;

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("NetSepio Contract", function() {

  before(async function() {
    this.value = new BN(1);
    accounts = await web3.eth.getAccounts();
    owner       = accounts[0];
    nonOwner    = accounts[1];
    netSepio = await NetSepio.new();
  });
  
  describe("Deployment", function() {
    it("Should return the right name and symbol of the token once it's deployed", async function() {
      assert.equal(await netSepio.name(), "NetSepio");
      assert.equal(await netSepio.symbol(), "NST");
    });

    it("should allow non owners to register", async function() {
      await netSepio.register({from: nonOwner});
    });
    
    it("Should not allow registration by the owner", async function() {
      await expectRevert(netSepio.register({from: owner}), 'Owner can not be a user');
    });

    it('reverts when transferring tokens to the zero address', async function () {
      await expectRevert(netSepio.transfer(constants.ZERO_ADDRESS, this.value, { from: nonOwner }), 'ERC20: transfer to the zero address');
    });
  });
});
