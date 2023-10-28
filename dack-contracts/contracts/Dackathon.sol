// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDackToken {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IBuilderContract {
    function isBuilderBlacklisted(address builderAddress) external view returns (bool);
}

contract Dackathon {
    struct Project {
        string name;
        string description;
        string pageLink;
        string githubLink;
        uint256 accepts;
        uint256 declines;
        Status status;
    }

    enum Status { Registration, Submission, Voting, Judging, Ended }

    struct Hackathon {
        string name;
        uint256 registrationEndTime;
        uint256 submissionEndTime;
        uint256 votingEndTime;
        uint256 judgingEndTime;
        uint256 dackReward;
        uint256 maxAccepts;
        uint256 maxDeclines;
        uint256 winner;
        Status status;
        address organizer;
        uint256[] projectIds;
        mapping(uint256 => Project) projects;
        mapping(address => bool) registeredBuilders;
    }

    Hackathon[] public hackathons;
    IDackToken public dackToken;
    IBuilderContract public builderContract;

    event HackathonAdded(uint256 indexed hackathonId, string name, address organizer);
    event RegistrationStarted(uint256 indexed hackathonId);
    event SubmissionStarted(uint256 indexed hackathonId);
    event VotingStarted(uint256 indexed hackathonId);
    event JudgingStarted(uint256 indexed hackathonId);
    event HackathonEnded(uint256 indexed hackathonId);
    event ProjectSubmitted(uint256 indexed hackathonId, uint256 indexed projectId, string name, address builder);
    event HackathonResult(uint256 indexed hackathonId, string name, uint256 winner);

    constructor(address _dackTokenAddress, address _builderContractAddress) {
        dackToken = IDackToken(_dackTokenAddress);
        builderContract = IBuilderContract(_builderContractAddress);
    }

    modifier onlyOrganizer(uint256 hackathonId) {
        require(msg.sender == hackathons[hackathonId].organizer, "Only the organizer can call this function");
        _;
    }

    modifier onlyRegistrant(uint256 hackathonId) {
        require(hackathons[hackathonId].registeredBuilders[msg.sender], "Only registered builders can call this function");
        _;
    }

    function createHackathon(
    string memory name,
    uint256 registrationEndTime,
    uint256 submissionEndTime,
    uint256 votingEndTime,
    uint256 judgingEndTime,
    uint256 dackReward,
    uint256 maxAccepts,
    uint256 maxDeclines
) external {
    require(registrationEndTime < submissionEndTime && submissionEndTime < votingEndTime && votingEndTime < judgingEndTime, "Invalid timeframes");
    uint256 hackathonId = hackathons.length;

    Hackathon storage newHackathon = hackathons.push();
    newHackathon.name = name;
    newHackathon.registrationEndTime = registrationEndTime;
    newHackathon.submissionEndTime = submissionEndTime;
    newHackathon.votingEndTime = votingEndTime;
    newHackathon.judgingEndTime = judgingEndTime;
    newHackathon.dackReward = dackReward;
    newHackathon.maxAccepts = maxAccepts;
    newHackathon.maxDeclines = maxDeclines;
    newHackathon.status = Status.Registration;
    newHackathon.organizer = msg.sender;

    emit HackathonAdded(hackathonId, name, msg.sender);
}

    function startRegistration(uint256 hackathonId) external onlyOrganizer(hackathonId) {
        require(hackathons[hackathonId].status == Status.Registration, "Hackathon is not in the registration phase");
        hackathons[hackathonId].status = Status.Submission;
        emit RegistrationStarted(hackathonId);
    }

    function endRegistration(uint256 hackathonId) external onlyOrganizer(hackathonId) {
        require(hackathons[hackathonId].status == Status.Submission, "Hackathon is not in the submission phase");
        hackathons[hackathonId].status = Status.Voting;
        emit SubmissionStarted(hackathonId);
    }

    function startVoting(uint256 hackathonId) external onlyOrganizer(hackathonId) {
        require(hackathons[hackathonId].status == Status.Voting, "Hackathon is not in the voting phase");
        hackathons[hackathonId].status = Status.Judging;
        emit VotingStarted(hackathonId);
    }

    function endVoting(uint256 hackathonId) external onlyOrganizer(hackathonId) {
        require(hackathons[hackathonId].status == Status.Judging, "Hackathon is not in the judging phase");
        hackathons[hackathonId].status = Status.Ended;
        emit JudgingStarted(hackathonId);
        uint256 projectId = hackathons[hackathonId].projectIds.length;
        uint256 maxAccepts = 0;
        uint256 maxDeclines = 0;
        uint256 winner = 0;

        for (uint256 i = 0; i < projectId; i++) {
            uint256 currentProjectId = hackathons[hackathonId].projectIds[i];
            if (hackathons[hackathonId].projects[currentProjectId].accepts > maxAccepts) {
                maxAccepts = hackathons[hackathonId].projects[currentProjectId].accepts;
                maxDeclines = hackathons[hackathonId].projects[currentProjectId].declines;
                winner = currentProjectId;
            } else if (hackathons[hackathonId].projects[currentProjectId].accepts == maxAccepts) {
                if (hackathons[hackathonId].projects[currentProjectId].declines < maxDeclines) {
                    maxDeclines = hackathons[hackathonId].projects[currentProjectId].declines;
                    winner = currentProjectId;
                }
            }
        }

        hackathons[hackathonId].winner = winner;
        emit HackathonResult(hackathonId, hackathons[hackathonId].name, winner);
    }

    function submitProject(uint256 hackathonId, string memory name, string memory description, string memory pageLink, string memory githubLink) external onlyRegistrant(hackathonId) {
        require(hackathons[hackathonId].status == Status.Submission, "Project submission is not allowed at this time");
        uint256 projectId = hackathons[hackathonId].projectIds.length + 1;
        hackathons[hackathonId].projectIds.push(projectId);
        hackathons[hackathonId].projects[projectId] = Project(name, description, pageLink, githubLink, 0, 0, Status.Registration);
        emit ProjectSubmitted(hackathonId, projectId, name, msg.sender);
    }

    function vote(uint256 hackathonId, uint256 projectId, uint256 value) external {
        require(hackathons[hackathonId].status == Status.Voting, "Voting is not allowed at this time");
        require(hackathons[hackathonId].projects[projectId].status == Status.Voting, "Voting is not allowed for this project");
        require(dackToken.transferFrom(msg.sender, address(this), value), "Token transfer failed");

        if (value > 0) {
            hackathons[hackathonId].projects[projectId].accepts += value;
        } else {
            hackathons[hackathonId].projects[projectId].declines += value;
        }
    }
}
