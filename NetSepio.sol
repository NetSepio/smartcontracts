pragma solidity ^0.6.0;

import {NS} from "./Token.sol";

contract NetSepio {
    address owner;
    NS token;
    enum UserType {normal, ip, vip}
    struct User {
        UserType userType;
        uint256 balance;
        uint256 totalVotesGiven;
        bool votingRight;
        uint256 joinedOnDate;
        uint256 dayCount;
    }

    enum WebsiteType {spam, malware, virus, safe}
    struct Website {
        string name;
        string domainName;
        mapping(WebsiteType => uint256) data;
        bool verdict;
        bool isExist;
    }

    struct Vote {
        string domainName;
        WebsiteType websiteType;
    }

    mapping(address => User) public Users;
    mapping(string => Website) public Websites;
    mapping(address => mapping(uint256 => Vote[])) public Votes;
    mapping(UserType => uint256) private VoteLimit;
    mapping(UserType => uint256) private AwardLimit;
    mapping(address => bool) private AppealForVotingRight;

    event UserRegister(address indexed user, uint256 timestamp);
    event UserVoted(
        address indexed user,
        string website,
        WebsiteType websiteType,
        uint256 timestamp
    );
    event WebsiteVerdict(
        string indexed domain,
        bool verdict,
        uint256 safe,
        uint256 spam,
        uint256 virus,
        uint256 malware,
        uint256 timestamp
    );
    event UserRewarded(address indexed user, uint256 amount, uint256 timestamp);
    event UserVotingRightRevoked(address user, uint256 timestamp);
    event UserVotingRightGranted(address user, uint256 timestamp);
    event UserAppealForVotingRight(address user, uint256 timestamp);
    event UpdatedAwardLimit(UserType _type, uint256 limit, uint256 timestamp);
    event UpdatedVotingLimit(UserType _type, uint256 limit, uint256 timestamp);

    constructor(address NSaddress) public {
        token = NS(NSaddress);
        owner = msg.sender;
        VoteLimit[UserType.normal] = 10;
        VoteLimit[UserType.ip] = 20;
        VoteLimit[UserType.vip] = 30;
        AwardLimit[UserType.normal] = 10;
        AwardLimit[UserType.ip] = 20;
        AwardLimit[UserType.vip] = 30;
    }

    function register() public {
        require(msg.sender != owner, "Owner can not be a user");
        User memory user = User({
            userType: UserType.normal,
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
        string memory _name,
        string memory _domainName,
        WebsiteType _type
    ) public {
        User storage user = Users[msg.sender];
        // has voting votingRight
        require(
            user.votingRight,
            "You do not have voting right now, if please appeal in case you have been banned"
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
        // vote for the website for the userType
        Vote memory newvote = Vote({
            domainName: _domainName,
            websiteType: _type
        });
        Votes[msg.sender][user.dayCount].push(newvote);
        emit UserVoted(msg.sender, _domainName, _type, block.timestamp);

        // update website data too
        Website storage site = Websites[_domainName];

        if (site.isExist) {
            site.data[_type]++;
            uint256 safeCount = site.data[WebsiteType.safe];
            uint256 spamCount = site.data[WebsiteType.spam];
            uint256 malwareCount = site.data[WebsiteType.malware];
            uint256 virusCount = site.data[WebsiteType.virus];
            if (
                safeCount > spamCount &&
                safeCount > malwareCount &&
                safeCount > virusCount
            ) {
                site.verdict = true;
            } else {
                site.verdict = false;
            }

            emit WebsiteVerdict(
                _domainName,
                site.verdict,
                safeCount,
                spamCount,
                virusCount,
                malwareCount,
                block.timestamp
            );
        } else {
            Website memory newsite = Website({
                name: _name,
                domainName: _domainName,
                verdict: false,
                isExist: true
            });
            Websites[_domainName] = newsite;
            Website storage newsite1 = Websites[_domainName];
            newsite1.data[WebsiteType.safe] = 0;
            newsite1.data[WebsiteType.spam] = 0;
            newsite1.data[WebsiteType.virus] = 0;
            newsite1.data[WebsiteType.malware] = 0;
            newsite1.data[_type]++;
            if (_type == WebsiteType.safe) {
                newsite1.verdict = true;
            }
            emit WebsiteVerdict(
                _domainName,
                newsite1.verdict,
                newsite1.data[WebsiteType.safe],
                newsite1.data[WebsiteType.spam],
                newsite1.data[WebsiteType.virus],
                newsite1.data[WebsiteType.malware],
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
        data[1] = site.data[WebsiteType.spam];
        data[2] = site.data[WebsiteType.malware];
        data[3] = site.data[WebsiteType.virus];
        return data;
    }
}
