const { expect } = require("chai")
const { ethers, assert, artifacts } = require("hardhat")
const {
    BN,
    constants,
    expectEvent,
    expectRevert,
    makeInterfaceId,
} = require("@openzeppelin/test-helpers")
const { read } = require("fs")
const NetSepio = artifacts.require("NetSepio")

let accounts
let netSepio
let admin
let moderator
let reviewer
let stranger

const INTERFACES = {
    ERC165: ["supportsInterface(bytes4)"],
    AccessControl: [
        "hasRole(bytes32,address)",
        "getRoleAdmin(bytes32)",
        "grantRole(bytes32,address)",
        "revokeRole(bytes32,address)",
        "renounceRole(bytes32,address)",
    ],
    AccessControlEnumerable: ["getRoleMember(bytes32,uint256)", "getRoleMemberCount(bytes32)"],
    ERC721: [
        "balanceOf(address)",
        "ownerOf(uint256)",
        "approve(address,uint256)",
        "getApproved(uint256)",
        "setApprovalForAll(address,bool)",
        "isApprovedForAll(address,address)",
        "transferFrom(address,address,uint256)",
        "safeTransferFrom(address,address,uint256)",
        "safeTransferFrom(address,address,uint256,bytes)",
    ],
    ERC721Enumerable: [
        "totalSupply()",
        "tokenOfOwnerByIndex(address,uint256)",
        "tokenByIndex(uint256)",
    ],
    ERC721Metadata: ["name()", "symbol()", "tokenURI(uint256)"],
}

const NETSEPIO_ADMIN_ROLE = ethers.utils.keccak256(Buffer.from("NETSEPIO_ADMIN_ROLE"))
const NETSEPIO_MODERATOR_ROLE = ethers.utils.keccak256(Buffer.from("NETSEPIO_MODERATOR_ROLE"))
const NETSEPIO_REVIEWER_ROLE = ethers.utils.keccak256(Buffer.from("NETSEPIO_REVIEWER_ROLE"))

describe("NetSepio Contract", function () {
    before(async function () {
        accounts = await ethers.getSigners()
        admin = accounts[0]
        moderator = accounts[1]
        reviewer = accounts[2]
        stranger = accounts[3]
        netSepio = await NetSepio.new("NetSepio", "NETSEC")
    })

    describe("Verify Structure", function () {
        it("Should return the right name and symbol of the token", async function () {
            assert.equal(await netSepio.name(), "NetSepio")
            assert.equal(await netSepio.symbol(), "NETSEC")

            let interfaceId = makeInterfaceId.ERC165(INTERFACES.ERC165)
            expect(await netSepio.supportsInterface(interfaceId)).to.equal(true)
            interfaceId = makeInterfaceId.ERC165(INTERFACES.ERC721)
            expect(await netSepio.supportsInterface(interfaceId)).to.equal(true)
            interfaceId = makeInterfaceId.ERC165(INTERFACES.ERC721Metadata)
            expect(await netSepio.supportsInterface(interfaceId)).to.equal(true)
            interfaceId = makeInterfaceId.ERC165(INTERFACES.ERC721Enumerable)
            expect(await netSepio.supportsInterface(interfaceId)).to.equal(true)
        })
    })

    describe("Roles Provisioning", function () {
        it("Should provision/verify admin, moderator and reviewer roles", async function () {
            const [admin, moderator, reviewer] = await hre.ethers.getSigners()

            expect(await netSepio.getRoleAdmin(NETSEPIO_ADMIN_ROLE)).to.equal(NETSEPIO_ADMIN_ROLE)
            expect(await netSepio.getRoleAdmin(NETSEPIO_MODERATOR_ROLE)).to.equal(
                NETSEPIO_ADMIN_ROLE
            )
            expect(await netSepio.getRoleAdmin(NETSEPIO_REVIEWER_ROLE)).to.equal(
                NETSEPIO_MODERATOR_ROLE
            )

            expect(await netSepio.hasRole(NETSEPIO_ADMIN_ROLE, admin.address)).to.equal(true)
            expect(await netSepio.hasRole(NETSEPIO_MODERATOR_ROLE, moderator.address)).to.equal(
                false
            )
            expect(await netSepio.hasRole(NETSEPIO_REVIEWER_ROLE, reviewer.address)).to.equal(false)

            let txReceipt = await netSepio.grantRole(NETSEPIO_MODERATOR_ROLE, moderator.address)
            expect(txReceipt.receipt.status).to.equal(true)
            expect(await netSepio.hasRole(NETSEPIO_MODERATOR_ROLE, moderator.address)).to.equal(
                true
            )
        })
    })
    describe("Netsepio ", () => {
        beforeEach(async () => {
            await netSepio.grantRole(NETSEPIO_MODERATOR_ROLE, admin.address)
            await netSepio.grantRole(NETSEPIO_REVIEWER_ROLE, admin.address)
        })
        it("To check the createReview && delegateReviewCreation", async () => {
            const data = ["A", "ABC", "www.XYZ.com", "B", "Hello", "Full", "www.artwork.ipfs.com"]

            //createReview
            expect(
                await netSepio.createReview(
                    data[0],
                    data[1],
                    data[2],
                    data[3],
                    data[4],
                    data[5],
                    data[6]
                )
            ).to.emit(NetSepio, "ReviewCreated")
            const readData = await netSepio.Reviews(1)

            expect(readData[0]).to.be.equal(data[0])

            const readMetadata = await netSepio.readMetadata(1)
            console.log(`readMetadata is ${readMetadata}`)

            //delegateReviewCreation
            expect(
                await netSepio.delegateReviewCreation(
                    "B",
                    data[1],
                    data[2],
                    data[3],
                    data[4],
                    data[5],
                    data[6],
                    admin.address
                )
            ).to.emit(NetSepio, "ReviewCreated")

            const readData2 = await netSepio.Reviews(2)
            expect(readData2[0]).to.be.equal("B")
        })
        it("to check updateReview", async () => {
            const oldData = await netSepio.Reviews(2)
            const newInfoHash = "Known"
            expect(await netSepio.updateReview(2, newInfoHash)).to.emit(NetSepio, "ReviewUpdated")
            const newData = await netSepio.Reviews(2)
            expect(oldData[6]).to.not.equal(newInfoHash)
            expect(newData[6]).to.be.equal(newInfoHash)
        })
        it("To check deleteReview", async () => {
            expect(await netSepio.deleteReview(2)).to.emit(NetSepio, "ReviewDeleted")
            expect(netSepio.ownerOf(2)).to.be.revertedWith("ERC721: invalid token ID")
        })
        it("to check the pause and unpause", async () => {
            expect(await netSepio.pause()).to.emit(NetSepio, "Paused")
            expect(netSepio.transferFrom(admin.address, moderator.address, 1)).to.be.reverted

            //to check the intial owner
            expect(await netSepio.ownerOf(1)).to.be.equal(admin.address)

            expect(await netSepio.unpause()).to.emit(NetSepio, "Unpaused")
            await netSepio.transferFrom(admin.address, moderator.address, 1)

            // to check the current owner
            expect(await netSepio.ownerOf(1)).to.be.equal(moderator.address)
        })
        it("to check the readMetadata", async () => {
            let readMetadata = await netSepio.readMetadata(1)

            const newInfoHash = "Known"

            await netSepio.updateReview(1, newInfoHash)

            readMetadata = await netSepio.readMetadata(1)

            expect(readMetadata).to.be.equal(newInfoHash)
        })
        it("to check tokenUri", async () => {
            const URI = await netSepio.tokenURI(1)
            expect(URI).to.be.equal("www.artwork.ipfs.com")
        })
    })
})
