// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {SetupTest} from "../Setup.t.sol";
// import {ILendingManager} from "../../src/interfaces/managers/lending/ILendingTerms.sol";
import {IERC4626} from "../../src/interfaces/token/IERC4626.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IHooks} from "../../src/interfaces/hooks/IHooks.sol";
import "../../src/interfaces/managers/lending/ILendingManager.sol";

contract LendingManagerTest is SetupTest {

    address lender = makeAddr("lender");
    function setUp() public override {
        super.setUp();
    }

    function testCreateLendingTerm() public {
        uint256 commission = 100; // 1% commission
        IHooks hooks = IHooks(address(mockHooks));

        // Create a lending term
        uint256 termId = lendingManager.createLendingTerm(commission, hooks);

        ILendingManager.LendingTermMetadata memory term = lendingManager.getLendingTerm(termId);

        // Verify the lending term properties
        assertEq(term.owner, address(this), "Owner should be the caller");
        assertEq(term.comission, commission, "Commission should match");
        assertEq(address(term.hooks), address(hooks), "Hooks address should match");
    }

    function testFreezeTermShares() public {

        // Params setup 
        uint256 comission = 100; // 1% commission
        IHooks hooks = IHooks(address(mockHooks));


        vm.prank(lender);
        // Create a lending term 
        uint256 termId = lendingManager.createLendingTerm(comission, hooks);

        // Depositor 1 deposits 1000 tokens
        address depositor = depositor1;
        uint256 depositAmount = 1000;

        vm.startPrank(depositor);
        token1.approve(address(assetManager), depositAmount);
        assetManager.deposit(address(token1), depositAmount);
        vm.stopPrank();












    }


}
