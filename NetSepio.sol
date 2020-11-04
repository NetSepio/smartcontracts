// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

import {NS} from "./Token.sol";

contract NetSepio {
    
    address owner;
    NS token;

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
    enum WebsiteTag {scam, fake, stereotype, hate}

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
    mapping(address => bool) private AppealForVotingRight;

    // Smart Contract Events
    event UserRegister(address indexed user, uint256 timestamp);
    event UserVoted(address indexed user, string website, WebsiteType websiteType, uint256 timestamp);
    event UserRewarded(address indexed user, uint256 amount, uint256 timestamp);
    event UserVotingRightRevoked(address user, uint256 timestamp);
    event UserVotingRightGranted(address user, uint256 timestamp);
    event UserAppealForVotingRight(address user, uint256 timestamp);
    event UpdatedAwardLimit(UserType _websiteType, uint256 limit, uint256 timestamp);
    event UpdatedVotingLimit(UserType _websiteType, uint256 limit, uint256 timestamp);

    constructor(address NSaddress) {
        token = NS(NSaddress);
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
        // has voting votingRights
        require(
            user.votingRights,
            "You do not have voting right now, please appeal in case you have been banned"
        );
        // has daily votes count left
        uint256 daysTillJoin = (block.timestamp - user.joinedOnDate) /
            60 /
            60 /
            24;
        user.dayCount = daysTillJoin;
        uint256 dailyVoteCount = Votes[msg.sender][user.dayCount].length;
        require(
            dailyVoteCount < VoteLimit[user.userType],
            "You do not have enough votes left for today"
        );

        // one domain one vote by one user
        bool userAlreadyVoted = false;
        Vote[] memory tempV = Votes[msg.sender][user.dayCount];
        for(uint i= 0; i< tempV.length; i++) {
            if( keccak256(abi.encodePacked(tempV[i].domainName)) == keccak256(abi.encodePacked(_domainName))) {
                userAlreadyVoted = true;
            }
        }

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
        emit UserVoted(msg.sender, _domainName, _websiteType, block.timestamp);

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
        }

        // mint token for the user and update balance
        user.totalVotesGiven++;
        user.balance += AwardLimit[user.userType];
        token._mint(msg.sender, AwardLimit[user.userType]);
        emit UserRewarded(
            msg.sender,
            AwardLimit[user.userType],
            block.timestamp
        );
    }

    function appealForVotingRight() public {
        require(msg.sender != owner, "Owner can not appeal");
        User storage user = Users[msg.sender];
        require(!user.votingRights, "You have voting right now also");
        AppealForVotingRight[msg.sender] = true;
        emit UserAppealForVotingRight(msg.sender, block.timestamp);
    }

    function revokeVotingRight(address _user) public {
        require(msg.sender == owner, "Only owner can block user");
        User storage user = Users[_user];
        user.votingRights = false;
        emit UserVotingRightRevoked(msg.sender, block.timestamp);
    }

    function grantVotingRightAfterAppeal(address _user) public {
        require(
            msg.sender == owner,
            "Only owner can grant voting right to user"
        );
        require(
            AppealForVotingRight[_user],
            "User should appeal first for voting right"
        );
        User storage user = Users[_user];
        user.votingRights = true;
        emit UserVotingRightGranted(msg.sender, block.timestamp);
    }

    function setVotingLimit(UserType _userType, uint256 limit) public {
        require(msg.sender == owner, "Only owner can set limit");
        VoteLimit[_userType] = limit;
        emit UpdatedVotingLimit(_userType, limit, block.timestamp);
    }

    function setAwardLimit(UserType _userType, uint256 award) public {
        require(msg.sender == owner, "Only owner can set limit");
        AwardLimit[_userType] = award;
        emit UpdatedVotingLimit(_userType, award, block.timestamp);
    }

    function getWebsiteVotingDetails(string memory domainName)
        public
        view
        returns (uint256[] memory)
    {
        Website storage site = Websites[domainName];
        uint256[] memory data;
        data[0] = site.typeData[WebsiteType.safe];
        data[1] = site.typeData[WebsiteType.adware];
        data[2] = site.typeData[WebsiteType.phishing];
        data[3] = site.typeData[WebsiteType.malware];
        data[4] = site.typeData[WebsiteType.spyware];
        return data;
    }
}
