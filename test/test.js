const { expect } = require("chai");
const { ethers, assert, artifacts } = require("hardhat");
const { BN, constants, expectEvent, expectRevert, makeInterfaceId } = require('@openzeppelin/test-helpers');
const NetSepio = artifacts.require("NetSepio");

let accounts;
let netSepio;
let admin;
let moderator;
let reviewer;
let stranger;

const INTERFACES = {
	ERC165: [
	  'supportsInterface(bytes4)',
	],
	AccessControl: [
	  'hasRole(bytes32,address)',
	  'getRoleAdmin(bytes32)',
	  'grantRole(bytes32,address)',
	  'revokeRole(bytes32,address)',
	  'renounceRole(bytes32,address)'
	],
	AccessControlEnumerable: [
	  'getRoleMember(bytes32,uint256)',
	  'getRoleMemberCount(bytes32)'
	],
	ERC721: [
	  'balanceOf(address)',
	  'ownerOf(uint256)',
	  'approve(address,uint256)',
	  'getApproved(uint256)',
	  'setApprovalForAll(address,bool)',
	  'isApprovedForAll(address,address)',
	  'transferFrom(address,address,uint256)',
	  'safeTransferFrom(address,address,uint256)',
	  'safeTransferFrom(address,address,uint256,bytes)',
	],
	ERC721Enumerable: [
	  'totalSupply()',
	  'tokenOfOwnerByIndex(address,uint256)',
	  'tokenByIndex(uint256)',
	],
	ERC721Metadata: [
	  'name()',
	  'symbol()',
	  'tokenURI(uint256)',
	]
};

const NETSEPIO_ADMIN_ROLE = ethers.utils.keccak256(Buffer.from('NETSEPIO_ADMIN_ROLE'));
const NETSEPIO_MODERATOR_ROLE = ethers.utils.keccak256(Buffer.from('NETSEPIO_MODERATOR_ROLE'));
const NETSEPIO_REVIEWER_ROLE = ethers.utils.keccak256(Buffer.from('NETSEPIO_REVIEWER_ROLE'));

describe("NetSepio Contract", function () {

	before(async function () {
		accounts = await ethers.getSigners();
		admin = accounts[0];
		moderator = accounts[1];
		reviewer = accounts[2];
		stranger = accounts[3];
		netSepio = await NetSepio.new("NetSepio", "NETSEC");
	});

	describe("Verify Structure", function () {
		it("Should return the right name and symbol of the token", async function () {
			assert.equal(await netSepio.name(), "NetSepio");
			assert.equal(await netSepio.symbol(), "NETSEC");

			let interfaceId = makeInterfaceId.ERC165(INTERFACES.ERC165);
			expect(await netSepio.supportsInterface(interfaceId)).to.equal(true);
			interfaceId = makeInterfaceId.ERC165(INTERFACES.ERC721);
			expect(await netSepio.supportsInterface(interfaceId)).to.equal(true);
			interfaceId = makeInterfaceId.ERC165(INTERFACES.ERC721Metadata);
			expect(await netSepio.supportsInterface(interfaceId)).to.equal(true);
			interfaceId = makeInterfaceId.ERC165(INTERFACES.ERC721Enumerable);
			expect(await netSepio.supportsInterface(interfaceId)).to.equal(true);
		});
	});

	describe("Roles Provisioning", function () {
		it('Should provision/verify admin, moderator and reviewer roles', async function () {
			const [admin, moderator, reviewer] = await hre.ethers.getSigners();
		
			expect(await netSepio.getRoleAdmin(NETSEPIO_ADMIN_ROLE)).to.equal(NETSEPIO_ADMIN_ROLE);
			expect(await netSepio.getRoleAdmin(NETSEPIO_MODERATOR_ROLE)).to.equal(NETSEPIO_ADMIN_ROLE);
			expect(await netSepio.getRoleAdmin(NETSEPIO_REVIEWER_ROLE)).to.equal(NETSEPIO_MODERATOR_ROLE);
			
			expect(await netSepio.hasRole(NETSEPIO_ADMIN_ROLE, admin.address)).to.equal(true);
			expect(await netSepio.hasRole(NETSEPIO_MODERATOR_ROLE, moderator.address)).to.equal(false);
			expect(await netSepio.hasRole(NETSEPIO_REVIEWER_ROLE, reviewer.address)).to.equal(false);
		
			let txReceipt = await netSepio.grantRole(NETSEPIO_MODERATOR_ROLE, moderator.address);
			expect(txReceipt.receipt.status).to.equal(true);
			expect(await netSepio.hasRole(NETSEPIO_MODERATOR_ROLE, moderator.address)).to.equal(true);
		});
	});
});
