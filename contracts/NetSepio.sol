//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

// import "./NetVote.sol";

abstract contract NetSepio is ERC721Pausable, ERC721Burnable, ERC721URIStorage, AccessControlEnumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;


    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    
    string private _baseTokenURI;

    mapping (address => mapping(string => bool)) private reviewToIPFSPath;

    constructor (
        string memory _name,
        string memory _symbol,
        string memory _baseuri
    ) ERC721(_name, _symbol) {
        _baseTokenURI = _baseuri;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        // _setupRole(VOTER_ROLE, _msgSender());
        _setupRole(MODERATOR_ROLE, _msgSender());
    }


    /** ========== public view functions ========== */

    function isModerator(address caller) public view returns (bool) {
        return _checkRole(MODERATOR_ROLE, caller);
    }

    /** ========== external mutative functions ========== */

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `MODERATOR_ROLE`.
     */
    function pause() external {
        require(hasRole(MODERATOR_ROLE, _msgSender()), "NetSepio: must have pauser role to pause");
        _pause();
    }

    
    /** ========== internal mutative functions ========== */

    // The IPFS path should be the CID + file.extension, e.g: [IPFSPath]/metadata.json
    // Therefore the length of '_path' may be longer than 46.
    function _setTokenIPFSPath(uint256 tokenId, string memory _path) internal {
        require(bytes(_path).length >= 46, "Invalid IPFS path");
        require(getCreatorUniqueIPFSHashAddress(_path), "NFT has been minted");

        _setTokenURI(tokenId, _path);

        IPFSPathset(tokenId, _path);
    }

    function _netMint(string memory _path) internal returns (uint256) {

        reviewToIPFSPath[_msgSender()][_path] = true;
        uint256 tokenId = _tokenIdTracker.current();

        _safeMint(to, tokenId);
        _tokenIdTracker.increment();
        _setTokenIPFSPath(tokenId, _path);

        return tokenId;
    }


    /** ========== internal view functions ========== */

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }


    /** ========== event ========== */
    event IPFSPathset(uint256 indexed tokenId, string _path);

}