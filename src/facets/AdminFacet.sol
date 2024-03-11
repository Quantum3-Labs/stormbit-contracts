pragma solidity 0.8.20;

import {IAdmin} from "../interfaces/IAdmin.sol";
import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import {Base} from "./Base.sol";

contract AdminFacet is IAdmin, Base {
    string public constant override name = "Admin";

    function setNewGovernor(address _newGov) external override {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (_newGov == address(0)) {
            revert OwnerCannotBeZeroAddress();
        }
        s.governor = _newGov;
    }

    function addSupportedToken(address _token) external override {}

    function removeSupportedToken(address _token) external override {}

    function addSupportedAgreement(address _agreement) external override {}

    function removeSupportedAgreement(address _agreement) external override {}

    function governor() external view override returns (address) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.governor;
    }
}
