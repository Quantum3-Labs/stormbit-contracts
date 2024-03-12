pragma solidity 0.8.20;

import {IRegistry} from "../interfaces/IRegistry.sol";
import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import {Base} from "./Base.sol";

contract RegistryFacet is IRegistry, Base {
    string public constant override name = "Registry";

    function register(string memory username) external override {
        AppStorage storage s = LibAppStorage.diamondStorage();
        // perform some logic here to register the user
        if (_hasUsername(msg.sender)) {
            revert UserAlreadyRegistered();
        }
        // check length of username
        if (
            bytes(username).length > 32 ||
            s.usedUsernames[keccak256(bytes(username))]
        ) {
            revert InvalidUsername();
        }

        s.usernames[msg.sender] = username;
        s.usedUsernames[keccak256(bytes(username))] = true;
    }

    function isRegistered(address user) external view override returns (bool) {
        return _hasUsername(user);
    }
}
