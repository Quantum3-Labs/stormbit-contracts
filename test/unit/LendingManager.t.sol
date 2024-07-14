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

        // Deposit tokens into the lending term
        uint256 shares = vaultToken1.balanceOf(depositor);
        vaultToken1.approve(address(lendingManager), shares);
        lendingManager.depositToTerm(termId, address(token1), shares);
        vm.stopPrank();

        // Get initial disposable shares
        (, uint256 initialDisposableShares,) = lendingManager.getLendingTermBalances(termId, address(token1));

        uint256 freezeSharesAmount = 500;
        vm.startPrank(address(loanManager));
        lendingManager.freezeTermShares(termId, freezeSharesAmount, address(token1));
        vm.stopPrank();

        // Get new disposable shares
        (, uint256 newDisposableShares,) = lendingManager.getLendingTermBalances(termId, address(token1));
        assertEq(newDisposableShares, initialDisposableShares - freezeSharesAmount, "Disposable shares should decrease");
    }

    function testExpectRevertFreezeTermSharesNonExistentTerm() public {
        uint256 freezeSharesAmount = 500;
        uint256 nonExistentTermId = 9999;
        ERC20Mock token1 = token1;

        vm.startPrank(address(loanManager));
        vm.expectRevert(abi.encodeWithSignature("LendingTermDoesNotExist()"));
        lendingManager.freezeTermShares(nonExistentTermId, freezeSharesAmount, address(token1));
        vm.stopPrank();
    }

    function testExpectRevertInsufficientDisposableShares() public {
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

        // Deposit tokens into the lending term
        uint256 shares = vaultToken1.balanceOf(depositor);
        vaultToken1.approve(address(lendingManager), shares);
        lendingManager.depositToTerm(termId, address(token1), shares);
        vm.stopPrank();

        // Get initial disposable shares
        (, uint256 initialDisposableShares,) = lendingManager.getLendingTermBalances(termId, address(token1));

        // Freeze more shares than available
        uint256 excessiveFreezeSharesAmount = initialDisposableShares + 1;
        vm.startPrank(address(loanManager));
        vm.expectRevert(abi.encodeWithSignature("InsufficientDisposableShares()"));
        lendingManager.freezeTermShares(termId, excessiveFreezeSharesAmount, address(token1));
        vm.stopPrank();
    }
}
