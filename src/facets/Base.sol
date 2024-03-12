pragma solidity 0.8.20;

import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";

/// @title Base contract for all facets
/// @author Quantum3 Labs <security@quantum3labs.com>
/// @notice This contract will host modifiers and custom errors

contract CustomErrors {
    error CallerIsNotGovernor();
    error OwnerCannotBeZeroAddress();
    error AlreadyInitialized();
    error UserAlreadyRegistered();
    error InvalidUsername();
    error TokenNotSupported(address token);
    error AgreementNotSupported(address agreement);
}

contract Events {
    event NewGovernor(address newGovernor);
    event AddSupportedToken(address token);
    event RemoveSupportedToken(address token);
    event AddSuppportedAgreement(address agreement);
    event RemoveSupportedAgreement(address agreement);
}

// TODO: Add reentrancy guard

contract Base is CustomErrors, Events {
    function _hasUsername(address _user) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return keccak256(bytes(s.usernames[_user])) != keccak256(bytes(""));
    }

    modifier onlyGovernor() {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (msg.sender != s.governor) {
            revert CallerIsNotGovernor();
        }
        _;
    }
    modifier onlyRegisteredUser() {
        require(_hasUsername(msg.sender), "User is not registered");
        _;
    }
}
