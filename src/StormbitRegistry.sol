// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IGovernable} from "./interfaces/utils/IGovernable.sol";
import {IInitialize} from "./interfaces/utils/IInitialize.sol";
import {IStormbitRegistry} from "./interfaces/IStormbitRegistry.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager
/// @notice entrypoint for all lender and lending terms operations

/// @dev Think of terms are minimal ERC4626, this contract is using word "shares" to represent ERC4626 assets, and "weight" to represent ERC4626 shares
contract StormbitRegistry is Initializable, IGovernable, IStormbitRegistry {
    address private _governor;

    mapping(address => string) public usernames;

    constructor(address initialGovernor) {
        _governor = initialGovernor;
    }

    function governor() public view override returns (address) {
        return _governor;
    }

    function register(string memory _username) external override {
        require(bytes(usernames[msg.sender]).length == 0, "StormbitRegistry: user already registered");
        require(bytes(_username).length > 0, "StormbitRegistry: username is empty");

        usernames[msg.sender] = _username;

        emit Registered(msg.sender, _username);
    }
}
