//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";


interface INetSepio {
    function isModerator(address caller) external view returns (bool);
    function checkReviewed(address reviewer, bytes32 siteName) external view returns (bool);
}

contract NetStatus is Ownable {

    struct SiteStatus {
        string siteUri;
        string[] tags;
        string siteType;
        string siteSafety;
    }

    mapping (bytes32 => netStatus) internal siteStatus;

    INetSepio private netSepio;

    constructor (address _netSepioAddress) {
        netSepio = INetSepio(_netSepioAddress);
    }

    /** ========== external mutative functions ========== */

    function setNewSite(
        bytes32 _siteName,
        string memory _siteUri
    ) external onlyModerator {
        SiteStatus memory site;
        
        site.siteUri = _siteUri;
        siteStatus[_siteName] = site;

        emit newSiteCreated(_siteName, _siteUri, _msgSender());
    }


    function changeNetSepioAddress(address newNetSepioAddress) external onlyOwner {
        require(newNetSepioAddress != address(0), "new NetSepio Address can not be null");

        netSepioAddress = newNetSepioAddress;

        emit netSepioAddressChanged(newNetSepioAddress);
    }

    function addSiteDetails(
        bytes32 _siteName,
        string memory _tag, 
        string memory _siteType, 
        string memory _siteSafety,
        address operator
        ) external {
            require(!netSepio.checkReviewed(_siteName, operator), "you have reviewd the site");

            SiteStatus storage site = siteStatus[_siteName];

            site.tags.push(_tag);
            site.siteType = _siteType;
            site.siteSafety = _siteSafety;
            
            emit siteDetailsAdded(_siteName, _tag, _siteType, _siteSafety, operator);
    }
    

    /** ========== modifier ========== */
    modifier onlyModerator() {
        require(netSepio.isModerator(_msgSender()), "caller must be the netSepio contract");
        _;
    }

    modifier onlyNetSepioContract() {
        require(address(netSepio) == _msgSender(), "caller must be NetSepio Contract");
        _;
    }

    /** ========== event ========== */
    event netSepioAddressChanged(address indexed newNetSepioAddress);

    event newSiteCreated(bytes32 indexed siteName, string siteUri, address moderator);

    event siteDetailsAdded(bytes32 indexed siteName, string tag, string siteType, string siteSafety, address operator);
}