interface INetStatus {
    function addSiteDetails(
            bytes32 _siteName,
            string memory _tag, 
            string memory _siteType, 
            string memory _siteSafety,
            address operator
        ) external;
}