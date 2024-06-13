pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {TestUtils} from "../Utils.t.sol";
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
        (, uint256 commission) = lendingManager.lendingTerms(termId);
        assert(commission == 0);
    }

    function testLendingTermRevert() public {
        vm.expectRevert();
        vm.prank(lender1);
        lendingManager.createLendingTerm(0);
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

        assert(
            lendingManager.userTotalDelegatedShares(
                depositor1,
                address(vaultToken1)
            ) == delegateAmount
        );
        (uint256 disposableAmount, ) = lendingManager.termOwnerShares(
            termId,
            address(vaultToken1)
        );
        assert(disposableAmount == delegateAmount);
    }
}
