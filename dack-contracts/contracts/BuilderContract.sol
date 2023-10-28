// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract BuilderContract {
    struct Builder {
        uint256 builderId;
        string builderName;
        string builderSkill;
        bool isBlacklisted;
    }

    mapping(address => Builder) public builders;
    address[] public builderAddresses;

    uint256 public nextBuilderId;

    constructor() {
        nextBuilderId = 1;
    }

    function createBuilder(string memory name, string memory skill) external {
        builders[msg.sender] = Builder(nextBuilderId, name, skill, false);
        builderAddresses.push(msg.sender);
        nextBuilderId++;
    }

    function updateBuilder(string memory name, string memory skill) external {
        Builder storage builder = builders[msg.sender];
        builder.builderName = name;
        builder.builderSkill = skill;
    }

    function blacklistBuilder(address builderAddress) external {
        Builder storage builder = builders[builderAddress];
        builder.isBlacklisted = true;
    }

    function unblacklistBuilder(address builderAddress) external {
        Builder storage builder = builders[builderAddress];
        builder.isBlacklisted = false;
    }

    function isBuilderBlacklisted(address builderAddress) external view returns (bool) {
        return builders[builderAddress].isBlacklisted;
    }

    function getBuilderById(uint256 builderId) external view returns (string memory, string memory) {
        for (uint256 i = 0; i < builderAddresses.length; i++) {
            if (builders[builderAddresses[i]].builderId == builderId) {
                return (builders[builderAddresses[i]].builderName, builders[builderAddresses[i]].builderSkill);
            }
        }
        revert("Builder not found");
    }

    function getBuilderByAddress(address builderAddress) external view returns (string memory, string memory, bool) {
        Builder storage builder = builders[builderAddress];
        require(builder.builderId > 0, "Builder not found");
        return (builder.builderName, builder.builderSkill, builder.isBlacklisted);
    }

    function getBuilderCount() external view returns (uint256) {
        return builderAddresses.length;
    }
}
