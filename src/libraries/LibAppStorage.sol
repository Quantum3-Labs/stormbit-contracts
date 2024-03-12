//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibDiamond} from "../libraries/LibDiamond.sol";

struct PoolStorage {
    string name;
    address owner;
    uint256 creditScore;
    uint256 maxAmountOfStakers;
    uint256 votingQuorum;
    uint256 maxPoolUsage;
    uint256 votingPowerCoolDown;
    mapping(address => bool) supportedAssets;
    mapping(address => bool) supportedAgreements;
}

struct AppStorage {
    bool initialized; // Flag indicating if the contract has been initialized
    address governor; // Address of the contract owner
    mapping(address => bool) supportedAssets; // Mapping of supported tokens
    mapping(address => bool) supportedAgreements; // Mapping of supported agreements
    mapping(address => string) usernames; // Mapping of usernames
    mapping(bytes32 => bool) usedUsernames; // Mapping of used usernames
    // Pools
    mapping(uint256 => PoolStorage) pools; // Mapping of lending pools
    mapping(uint256 => mapping(address => uint256)) balance; // maps poolId to token to balance
    uint256 poolCount; // Count of lending pools
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}
