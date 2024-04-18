//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibDiamond} from "../libraries/LibDiamond.sol";

struct Loan {
    uint256 loanId;
    uint256 support;
    mapping(address => uint256) supporters;
}

struct PoolStorage {
    string name;
    address owner;
    address assetVault;
    uint256 creditScore;
    uint256 maxAmountOfStakers;
    uint256 votingQuorum;
    uint256 maxPoolUsage;
    uint256 votingPowerCoolDown;
    uint256 totalShares; // Total shares of the pool
    mapping(address => uint256) userShare; // maps user to token to shares ( USER SHARES ON THE POOL )
    mapping(uint256 => Loan) loans;
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
    mapping(uint256 => uint256) poolShare; // maps pool to token to used balance
    mapping(uint256 => uint256) poolUsedShares;
    uint256 totalShares;
    uint256 poolCount; // Count of lending pools
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}
