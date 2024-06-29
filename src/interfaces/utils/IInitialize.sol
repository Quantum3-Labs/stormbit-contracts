// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Initialize Interface
interface IInitialize {
    function initialize(
        address loanManagerAddr,
        address lendingManagerAddr
    ) external;
}
