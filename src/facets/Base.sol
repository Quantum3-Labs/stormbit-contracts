pragma solidity 0.8.20;

import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";

/// @title Base contract for all facets
/// @author Quantum3 Labs <security@quantum3labs.com>
/// @notice This contract will host modifiers and custom errors

contract CustomErrors {
    error CallerIsNotGovernor();
    error OwnerCannotBeZeroAddress();
    error AlreadyInitialized();
}

// TODO: Add reentrancy guard

contract Base is CustomErrors {
    modifier onlyGovernor() {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (msg.sender != s.governor) {
            revert CallerIsNotGovernor();
        }
        _;
    }
}
