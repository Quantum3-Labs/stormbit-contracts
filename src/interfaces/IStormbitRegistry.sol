// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Registry Interface
interface IStormbitRegistry {
    event Registered(address indexed user, string username);

    function register(string memory) external;
}
