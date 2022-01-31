const { expect } = require("chai");
const { assert } = require("hardhat");
const NetSepio = artifacts.require("NetSepio");
const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

let accounts;
let netSepio;
let owner;
let moderator;
let voter;
let stranger;

// Vanilla Mocha test. Increased compatibility with tools that integrate Mocha.
describe("NetSepio Contract", function () {

	before(async function () {
		accounts = await web3.eth.getAccounts();
		owner = accounts[0];
		moderator = accounts[1];
		voter = accounts[2];
		stranger = accounts[3];
		netSepio = await NetSepio.new("NetSepio", "NETSEC");
	});

	// TODO: Perform complete coverage tests
	describe("NetSepio deployment", function () {
		it("Should return the right name and symbol of the token once NetSepio is deployed", async function () {
			assert.equal(await netSepio.name(), "NetSepio");
			assert.equal(await netSepio.symbol(), "NETSEC");
		});
	});
});
