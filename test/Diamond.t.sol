pragma solidity 0.8.20;

import {Setup, console} from "./Setup.sol";
import {IAdmin} from "../src/interfaces/IAdmin.sol";
import {Errors} from "../src/libraries/Common.sol";

contract DiamondTest is Setup {
    function test_AdminFacet() public {
        IAdmin admin = IAdmin(address(stormbit));
        require(admin.governor() == governor, "governor should be equal to the setup governor");
        vm.expectRevert(Errors.CallerIsNotGovernor.selector);
        admin.setNewGovernor(address(0));

        vm.prank(governor);
        admin.setNewGovernor(address(this));
        require(admin.governor() == address(this), "governor should be equal to the new governor");
    }
}
