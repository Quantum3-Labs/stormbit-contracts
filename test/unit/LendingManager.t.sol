pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {SetupTest} from "../Setup.t.sol";
import {ILendingTerms} from "../../src/interfaces/ILendingTerms.sol";
import {IERC4626} from "../../src/interfaces/IERC4626.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract LendingManagerTest is SetupTest {
    uint256 depositAmount;
    uint256 delegateAmount;

    function setUp() public {
        SetupTest.setUpEnvironment();
        depositAmount = 1_000 * (10 ** token1.decimals());
        delegateAmount = 500 * (10 ** vaultToken1.decimals());
    }

    function testRegister() public {
        vm.prank(lender1);
        lendingManager.register();

        assert(lendingManager.isRegistered(lender1));
    }

    function testCreateLendingTerm() public {
        vm.startPrank(lender1);
        lendingManager.register();
        uint256 termId = lendingManager.createLendingTerm(0);
        (, uint256 commission, ) = lendingManager.lendingTerms(termId);
        assert(commission == 0);
    }

    function testNotLenderCreateLendingTermRevert() public {
        vm.expectRevert();
        vm.prank(lender1);
        lendingManager.createLendingTerm(0);
    }

    function testRemoveLendingterm() public {
        vm.startPrank(lender1);
        lendingManager.register();
        uint256 termId = lendingManager.createLendingTerm(5);
        lendingManager.removeLendingTerm(termId);
        vm.stopPrank();

        (, uint256 commission, ) = lendingManager.lendingTerms(termId);
        assert(commission == 0);
    }

    function testRemoveLendingTermRevert() public {
        vm.startPrank(lender1);
        lendingManager.register();
        uint256 termId = lendingManager.createLendingTerm(5);
        vm.stopPrank();

        vm.startPrank(depositor1);
        // deposit some token to vault by asset manager
        token1.approve(address(assetManager), depositAmount);
        assetManager.deposit(address(token1), depositAmount);
        // delegate shares to lender1
        lendingManager.increaseDelegateToTerm(
            termId,
            address(token1),
            delegateAmount
        );
        vm.stopPrank();

        // now the term has shares, should not be able to remove
        vm.expectRevert();
        vm.startPrank(lender1);
        lendingManager.removeLendingTerm(termId);
    }

    function testIncreaseDeletegateToTerm() public {
        // register and create new term with 5% commission
        vm.startPrank(lender1);
        lendingManager.register();
        uint256 termId = lendingManager.createLendingTerm(5);
        vm.stopPrank();

        vm.startPrank(depositor1);
        // deposit some token to vault by asset manager
        token1.approve(address(assetManager), depositAmount);
        assetManager.deposit(address(token1), depositAmount);
        // delegate shares to lender1
        lendingManager.increaseDelegateToTerm(
            termId,
            address(token1),
            delegateAmount
        );
        vm.stopPrank();

        (uint256 disposableAmount, ) = lendingManager.termOwnerShares(
            termId,
            address(vaultToken1)
        );
        address[] memory termDepositors = lendingManager.getTermDepositors(
            termId,
            address(vaultToken1)
        );
        uint256 userTotalDelagatedShares = lendingManager
            .userTotalDelegatedShares(depositor1, address(vaultToken1));
        uint256 userDisposableSharesOnTerm = lendingManager
            .getUserDisposableSharesOnTerm(
                termId,
                depositor1,
                address(vaultToken1)
            );

        assert(termDepositors.length == 1);
        assert(termDepositors[0] == depositor1);
        assert(userTotalDelagatedShares == delegateAmount);
        assert(disposableAmount == delegateAmount);
        assert(userDisposableSharesOnTerm == delegateAmount);
    }
}
