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
        bool votingRight;
        uint256 joinedOnDate;
        uint256 dayCount;
    }

    enum WebsiteType {spyware, malware, phishing, adware, safe}
    enum WebsiteTag {scam, fake, stereotype, hate}

    struct Website {
        string domainName;
        mapping(WebsiteType => uint256) data;
        bool verdict;
        bool isExist;
    }

    struct Vote {
        string domainName;
        string websiteURL;
        WebsiteType websiteType;
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
    event WebsiteVerdict(string indexed domain, bool verdict, uint256 safe, uint256 adware, uint256 phishing, uint256 malware, uint256 spyware, uint256 timestamp);
    event UserRewarded(address indexed user, uint256 amount, uint256 timestamp);
    event UserVotingRightRevoked(address user, uint256 timestamp);
    event UserVotingRightGranted(address user, uint256 timestamp);
    event UserAppealForVotingRight(address user, uint256 timestamp);
    event UpdatedAwardLimit(UserType _type, uint256 limit, uint256 timestamp);
    event UpdatedVotingLimit(UserType _type, uint256 limit, uint256 timestamp);

    constructor(address NSaddress) public {
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
            votingRight: true,
            joinedOnDate: block.timestamp,
            dayCount: 0
        });
        Users[msg.sender] = user;
        emit UserRegister(msg.sender, user.joinedOnDate);
    }

    function vote(
        string memory _domainName,
        string memory _websiteURL,
        WebsiteType _type,
        string memory _metadataHash
    ) public {
        User storage user = Users[msg.sender];
        // has voting votingRight
        require(
            user.votingRight,
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
            websiteType: _type,
            metadataHash: _metadataHash
        });
        Votes[msg.sender][user.dayCount].push(newvote);
        emit UserVoted(msg.sender, _domainName, _type, block.timestamp);

        // update website data too
        Website storage site = Websites[_domainName];

        if (site.isExist) {
            site.data[_type]++;
            uint256 safeCount = site.data[WebsiteType.safe];
            uint256 adwareCount = site.data[WebsiteType.adware];
            uint256 phishingCount = site.data[WebsiteType.phishing];
            uint256 malwareCount = site.data[WebsiteType.malware];
            uint256 spywareCount = site.data[WebsiteType.spyware];
            if (
                safeCount > adwareCount &&
                safeCount > phishingCount &&
                safeCount > malwareCount &&
                safeCount > spywareCount
            ) {
                site.verdict = true;
            } else {
                site.verdict = false;
            }

            emit WebsiteVerdict(
                _domainName,
                site.verdict,
                safeCount,
                adwareCount,
                phishingCount,
                malwareCount,
                spywareCount,
                block.timestamp
            );
        } else {
            Website memory newsite = Website({
                domainName: _domainName,
                verdict: false,
                isExist: true
            });
            Websites[_domainName] = newsite;
            Website storage newsite1 = Websites[_domainName];
            newsite1.data[WebsiteType.safe] = 0;
            newsite1.data[WebsiteType.adware] = 0;
            newsite1.data[WebsiteType.phishing] = 0;
            newsite1.data[WebsiteType.malware] = 0;
            newsite1.data[WebsiteType.spyware] = 0;
            newsite1.data[_type]++;
            if (_type == WebsiteType.safe) {
                newsite1.verdict = true;
            }
            emit WebsiteVerdict(
                _domainName,
                _websiteURL,
                newsite1.verdict,
                newsite1.data[WebsiteType.safe],
                newsite1.data[WebsiteType.adware],
                newsite1.data[WebsiteType.phishing],
                newsite1.data[WebsiteType.malware],
                newsite1.data[WebsiteType.spyware],
                block.timestamp
            );
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
        require(!user.votingRight, "You have voting right now also");
        AppealForVotingRight[msg.sender] = true;
        emit UserAppealForVotingRight(msg.sender, block.timestamp);
    }

    function revokeVotingRight(address _user) public {
        require(msg.sender == owner, "Only owner can block user");
        User storage user = Users[_user];
        user.votingRight = false;
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
        user.votingRight = true;
        emit UserVotingRightGranted(msg.sender, block.timestamp);
    }

    function setVotingLimit(UserType _type, uint256 limit) public {
        require(msg.sender == owner, "Only owner can set limit");
        VoteLimit[_type] = limit;
        emit UpdatedVotingLimit(_type, limit, block.timestamp);
    }

    function setAwardLimit(UserType _type, uint256 award) public {
        require(msg.sender == owner, "Only owner can set limit");
        AwardLimit[_type] = award;
        emit UpdatedVotingLimit(_type, award, block.timestamp);
    }

    function getWebsiteVotingDetails(string memory domainName)
        public
        view
        returns (uint256[] memory)
    {
        Website storage site = Websites[domainName];
        uint256[] memory data;
        data[0] = site.data[WebsiteType.safe];
        data[1] = site.data[WebsiteType.adware];
        data[2] = site.data[WebsiteType.phishing];
        data[3] = site.data[WebsiteType.malware];
        data[4] = site.data[WebsiteType.spyware];
        return data;
    }
}
