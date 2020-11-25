// SPDX-License-Identifier: MIT

pragma solidity ^0.7.5;

import "./ERC20.sol";

contract NetSepio is ERC20 {
    
    address owner;

    enum UserType {scout, sentry, sentinel}
    struct User {
        UserType userType;
        uint256 balance;
        uint256 totalVotesGiven;
        bool votingRights;
        uint256 joinedOnDate;
        uint256 dayCount;
    }

    enum WebsiteType {spyware, malware, phishing, adware, safe}
    enum WebsiteTag {scam, fake, stereotype, hate, genuine}

    struct Website {
        string domainName;
        mapping(WebsiteType => uint256) typeData;
        mapping(WebsiteTag => uint256) tagData;
        bool isExist;
    }

    struct Vote {
        string domainName;
        string websiteURL;
        WebsiteType websiteType;
        WebsiteTag websiteTag;
        string metadataHash;
    }

    mapping(address => User) public Users;
    mapping(string => Website) public Websites;
    mapping(address => mapping(uint256 => Vote[])) public Votes;
    mapping(UserType => uint256) private VoteLimit;
    mapping(UserType => uint256) private AwardLimit;
    mapping(address => bool) private AppealForVotingRights;

    // Smart Contract Events
    event UserRegister(address indexed user, uint256 timestamp);
    event UserVoted(address indexed user, string domain, string websiteURL, WebsiteType websiteType, WebsiteTag websiteTag, uint256 timestamp);
    event UserRewarded(address indexed user, uint256 amount, uint256 timestamp);
    event UserVotingRightsRevoked(address user, uint256 timestamp);
    event UserVotingRightsGranted(address user, uint256 timestamp);
    event UserAppealForVotingRights(address user, uint256 timestamp);
    event UpdatedVotingAndRewardsLimit(UserType _userType, uint256 dailyLimit, uint256 rewards, uint256 timestamp);

    constructor () ERC20("NetSepio", "NST") {
        owner = msg.sender;
        VoteLimit[UserType.scout] = 10;
        VoteLimit[UserType.sentry] = 20;
        VoteLimit[UserType.sentinel] = 30;
        AwardLimit[UserType.scout] = 1;
        AwardLimit[UserType.sentry] = 2;
        AwardLimit[UserType.sentinel] = 3;
    }

    function register() public {
        require(msg.sender != owner, "Owner can not be a user");
        User memory user = User({
            userType: UserType.scout,
            balance: 0,
            totalVotesGiven: 0,
            votingRights: true,
            joinedOnDate: block.timestamp,
            dayCount: 0
        });
        Users[msg.sender] = user;
        emit UserRegister(msg.sender, user.joinedOnDate);
    }

    function vote(
        string memory _domainName,
        string memory _websiteURL,
        WebsiteType _websiteType,
        WebsiteTag _websiteTag,
        string memory _metadataHash
    ) public {
        User storage user = Users[msg.sender];
        // Check for voting rights
        require(user.votingRights, "You do not have voting rights, please appeal in case you have been banned");
        // has daily votes count left
        uint256 daysTillJoin = (block.timestamp - user.joinedOnDate) / 60 / 60 / 24;
        user.dayCount = daysTillJoin;
        uint256 dailyVoteCount = Votes[msg.sender][user.dayCount].length;
        // Check for daily voting limits
        require(dailyVoteCount < VoteLimit[user.userType], "You do not have enough votes left for today");

        // one domain one vote by one user
        bool userAlreadyVoted = false;
        Vote[] memory tempV = Votes[msg.sender][user.dayCount];
        for(uint i= 0; i< tempV.length; i++) {
            if( keccak256(abi.encodePacked(tempV[i].domainName)) == keccak256(abi.encodePacked(_domainName))) {
                userAlreadyVoted = true;
            }
        }

        // check if user already voted for this domain
        require(!userAlreadyVoted, "You have already voted for this domain");

        // vote for the website for the userType
        Vote memory newvote = Vote({
            domainName: _domainName,
            websiteURL: _websiteURL,
            websiteType: _websiteType,
            websiteTag: _websiteTag,
            metadataHash: _metadataHash
        });
        Votes[msg.sender][user.dayCount].push(newvote);
        
        // update website data too
        Website storage site = Websites[_domainName];

        if (site.isExist) {
            site.typeData[_websiteType]++;
            site.tagData[_websiteTag]++;
        } else {
            Website storage newWebSite = Websites[_domainName];
            newWebSite.domainName = _domainName;
            newWebSite.isExist = true;
            newWebSite.typeData[WebsiteType.safe] = 0;
            newWebSite.typeData[WebsiteType.adware] = 0;
            newWebSite.typeData[WebsiteType.phishing] = 0;
            newWebSite.typeData[WebsiteType.malware] = 0;
            newWebSite.typeData[WebsiteType.spyware] = 0;
            newWebSite.typeData[_websiteType]++;
            newWebSite.tagData[WebsiteTag.scam] = 0;
            newWebSite.tagData[WebsiteTag.fake] = 0;
            newWebSite.tagData[WebsiteTag.stereotype] = 0;
            newWebSite.tagData[WebsiteTag.hate] = 0;
            newWebSite.tagData[WebsiteTag.genuine] = 0;
            newWebSite.tagData[_websiteTag]++;
        }

        emit UserVoted(msg.sender, _domainName, _websiteURL, _websiteType, _websiteTag, block.timestamp);

        // mint token for the user and update balance
        user.totalVotesGiven++;
        user.balance += AwardLimit[user.userType];
        _mint(msg.sender, AwardLimit[user.userType]);
        emit UserRewarded(msg.sender, AwardLimit[user.userType], block.timestamp);
    }

    function appealForVotingRights() public {
        require(msg.sender != owner, "Owner can not appeal");
        User storage user = Users[msg.sender];
        require(!user.votingRights, "You already have voting rights");
        AppealForVotingRights[msg.sender] = true;
        emit UserAppealForVotingRights(msg.sender, block.timestamp);
    }

    function revokeVotingRight(address _user) public {
        require(msg.sender == owner, "Only owner can block user");
        User storage user = Users[_user];
        user.votingRights = false;
        emit UserVotingRightsRevoked(_user, block.timestamp);
    }

    function grantVotingRightsAfterAppeal(address _user) public {
        require(msg.sender == owner, "Only owner can grant voting rights to user");
        require(AppealForVotingRights[_user], "User should appeal first for voting rights");
        User storage user = Users[_user];
        user.votingRights = true;
        AppealForVotingRights[_user] = false;
        emit UserVotingRightsGranted(_user, block.timestamp);
    }

    function setVotingLimit(UserType _userType, uint256 _dailyLimit, uint256 _rewards) public {
        require(msg.sender == owner, "Only owner can set daily voting limit");
        VoteLimit[_userType] = _dailyLimit;
        AwardLimit[_userType] = _rewards;
        emit UpdatedVotingAndRewardsLimit(_userType, _dailyLimit, _rewards, block.timestamp);
    }

    function getWebsiteVotingDetails(string memory _domainName)
        public
        view
        returns (uint256 spyware, uint256 malware, uint256 phishing, uint256 adware, uint256 safe, uint256 scam, uint256 fake, uint256 stereotype, uint256 hate, uint256 genuine)
    {
        Website storage website = Websites[_domainName];
        spyware = website.typeData[WebsiteType.spyware];
        malware = website.typeData[WebsiteType.malware];
        phishing = website.typeData[WebsiteType.phishing];
        adware = website.typeData[WebsiteType.adware];
        safe = website.typeData[WebsiteType.safe];
        scam = website.tagData[WebsiteTag.scam];
        fake = website.tagData[WebsiteTag.fake];
        stereotype = website.tagData[WebsiteTag.stereotype];
        hate = website.tagData[WebsiteTag.hate];
        genuine = website.tagData[WebsiteTag.genuine];
    }
}
