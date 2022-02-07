//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";

/**
 * @dev {ERC721} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *  - token ID and URI autogeneration
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract NetSepio is
    Context,
    AccessControlEnumerable,
    ReentrancyGuard,
    ERC721Enumerable,
    ERC721Pausable
{
    using Counters for Counters.Counter;

    bytes32 public constant NETSEPIO_ADMIN_ROLE = keccak256("NETSEPIO_ADMIN_ROLE");
    bytes32 public constant NETSEPIO_MODERATOR_ROLE = keccak256("NETSEPIO_MODERATOR_ROLE");
    bytes32 public constant NETSEPIO_VOTER_ROLE = keccak256("NETSEPIO_VOTER_ROLE");

    Counters.Counter private _tokenIdTracker;

    mapping(uint256 => string) private _tokenURI;

    struct Review {
        string category;
        string domainAddress;
        string siteURL;
        string siteType;
        string siteTag;
        string siteSafety;
        string infoHash;
    }

    mapping(uint256 => Review) public Reviews;

    event ReviewCreated(address indexed receiver, uint256 indexed tokenId, string category, string domainAddress, string siteURL, string siteType, string siteTag, string siteSafety, string metadataURI);
    event ReviewDeleted(address indexed ownerOrApproved, uint256 indexed tokenId);
    event ReviewUpdated(address indexed ownerOrApproved, uint256 indexed tokenId, string oldInfoHash, string newInfoHash);

    /**
     * @dev Grants `NETSEPIO_ADMIN_ROLE`, `NETSEPIO_VOTER_ROLE` and `NETSEPIO_MODERATOR_ROLE` to the
     * account that deploys the contract.
     *
     * Token URIs will be autogenerated based on `baseURI` and their token IDs.
     * See {ERC721-tokenURI}.
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _setupRole(NETSEPIO_ADMIN_ROLE, _msgSender());

        _setRoleAdmin(NETSEPIO_ADMIN_ROLE, NETSEPIO_ADMIN_ROLE);
        _setRoleAdmin(NETSEPIO_MODERATOR_ROLE, NETSEPIO_ADMIN_ROLE);
        _setRoleAdmin(NETSEPIO_VOTER_ROLE, NETSEPIO_MODERATOR_ROLE);
    }

    /**
     * @dev Creates a new token for `to`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_safeMint}.
     *
     * Requirements:
     *
     * - the caller must have the `NETSEPIO_VOTER_ROLE`.
     */
    function createReview(string memory category, string memory domainAddress, string memory siteURL, string memory siteType, string memory siteTag, string memory siteSafety, string memory metadataURI) public nonReentrant onlyRole(NETSEPIO_VOTER_ROLE) {
        require(hasRole(NETSEPIO_VOTER_ROLE, _msgSender()), "NetSepio: must have voter role to submit review");

        uint256 tokenId = _tokenIdTracker.current();
        _safeMint(_msgSender(), tokenId);
        
        // Create Mapping
        Review memory review = Review({
            category: category,
            domainAddress: domainAddress,
            siteURL: siteURL,
            siteType: siteType,
            siteTag: siteTag,
            siteSafety: siteSafety,
            infoHash: ""
        });
        Reviews[tokenId] = review;
        _tokenURI[tokenId] = metadataURI;
        _tokenIdTracker.increment();

        emit ReviewCreated(_msgSender(), tokenId, category, domainAddress, siteURL, siteType, siteTag, siteSafety, metadataURI);
    }

    function delegateReviewCreation(string memory category, string memory domainAddress, string memory siteURL, string memory siteType, string memory siteTag, string memory siteSafety, string memory metadataURI, address voter) public onlyRole(NETSEPIO_MODERATOR_ROLE) {
        require(hasRole(NETSEPIO_MODERATOR_ROLE, _msgSender()), "NetSepio: must have moderator role to submit review");

        uint256 tokenId = _tokenIdTracker.current();
        _safeMint(voter, tokenId);

        // Create Mapping
        Review memory review = Review({
            category: category,
            domainAddress: domainAddress,
            siteURL: siteURL,
            siteType: siteType,
            siteTag: siteTag,
            siteSafety: siteSafety,
            infoHash: ""
        });
        Reviews[tokenId] = review;
        _tokenURI[tokenId] = metadataURI;
        _tokenIdTracker.increment();

        emit ReviewCreated(voter, tokenId, category, domainAddress, siteURL, siteType, siteTag, siteSafety, metadataURI);
    }

    /**
     * @dev Destroys (Burns) an existing `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function deleteReview(uint256 tokenId) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NetSepio: caller is not owner nor approved to delete review");
        
        // destroy (burn) the token.
        _burn(tokenId);
        emit ReviewDeleted(_msgSender(), tokenId);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "NetSepio: tokenURI query for nonexistent token");
        return _tokenURI[tokenId];
    }

    /**
    * @dev Reads the metadata of a specified token. Returns the current infoHash in
    * storage of `tokenId`.
    *
    * @param tokenId The token to read the data off.
    *
    * @return A string representing the current infoHash mapped with the tokenId.
    */
    function readMetadata(uint256 tokenId) public virtual view returns (string memory) {
        return Reviews[tokenId].infoHash;
    }

    /**
    * @dev Updates the metadata of a specified token. Writes `newInfoHash` into storage
    * of `tokenId`.
    *
    * @param tokenId The token to write metadata to.
    * @param newInfoHash The metadata to be written to the token.
    *
    * Emits a `ReviewUpdate` event.
    */
    function updateReview(uint256 tokenId, string memory newInfoHash) public {
        require(hasRole(NETSEPIO_MODERATOR_ROLE, _msgSender()) || _isApprovedOrOwner(_msgSender(), tokenId), "NetSepio: caller do not have the authority");

        emit ReviewUpdated(_msgSender(), tokenId, Reviews[tokenId].infoHash, newInfoHash);
        Reviews[tokenId].infoHash = newInfoHash;
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `NETSEPIO_MODERATOR_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(NETSEPIO_ADMIN_ROLE, _msgSender()), "NetSepio: must have admin role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `NETSEPIO_MODERATOR_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(NETSEPIO_ADMIN_ROLE, _msgSender()), "NetSepio: must have admin role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}