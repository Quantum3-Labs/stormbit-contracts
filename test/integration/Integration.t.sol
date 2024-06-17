pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SetupTest} from "../Setup.t.sol";
import {BaseVault} from "../../src/vaults/BaseVault.sol";
import {ILoanRequest} from "../../src/interfaces/managers/loan/ILoanRequest.sol";

contract IntegrationTest is SetupTest {
    function setUp() public {
        SetupTest.setUpEnvironment();
    }

    // todo: think some better name
    /// @dev this is the integrtion test case for
    /// 2 depositors, 1 term, 1 lender, 1 borrower
    /// borrower borrow 1000 token1
    /// lender create a term with 5% commission
    /// depositor1 deposit 1000 token1 and delegate 1000 to lender1
    /// depositor2 deposit 1000 token1 and delegate 1000 to lender1
    /// lender allocate term with 5% commission to loan
    /// lender allocate 1000 shares to loan
    /// borrower execute loan
    /// borrower repay loan
    function testIntegration1() public {
        // borrower request loan
        // uint256 borrowAmount = 1000 * (10 ** token1.decimals());
        // uint256 loanId = _requestLoan(
        //     borrower1,
        //     address(token1),
        //     borrowAmount,
        //     1 days
        // );
        // uint256 termId = _registerAndCreateTerm(lender1, 500);
        // _depositAndDelegate(depositor1, 1000, 1000, address(token1), termId);
        // _depositAndDelegate(depositor2, 1000, 1000, address(token1), termId);
        // // check total shares on vault 1
        // uint256 totalShares = BaseVault(
        //     assetManager.getTokenVault(address(token1))
        // ).totalSupply();
        // console.log("total shares on vault 1: ", totalShares);
        // // get loan
        // ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
        // console.log("loan required shares1: ", loan.sharesRequired);
        // _allocateTermAndFundOnLoan(
        //     lender1,
        //     address(token1),
        //     loanId,
        //     termId,
        //     1000
        // );
        // // borrower execute loan
        // vm.prank(borrower1);
        // loanManager.executeLoan(loanId);
        // // mint 5% interest to borrower to pay extra
        // uint256 interest = (borrowAmount * 500) / 10000;
        // token1.mint(borrower1, interest);
        // // borrower repay loan
        // vm.startPrank(borrower1);
        // token1.approve(address(assetManager), borrowAmount + interest);
        // loanManager.repay(loanId);
        // vm.stopPrank();
    }

    /// @dev this is the integrtion test case for
    /// 2 depositors, 2 term, 2 lender, 1 borrower
    /// borrower borrow 1000 token1
    /// lender1 create a term with 5% commission
    /// lender2 create a term with 10% commission
    /// depositor1 deposit 1000 token1 and delegate 1000 to lender1
    /// depositor2 deposit 1000 token1 and delegate 1000 to lender2
    /// lender1 allocate term with 5% commission to loan
    /// lender2 allocate term with 10% commission to loan
    /// lender1 allocate 500 shares to loan
    /// lender2 allocate 500 shares to loan
    /// borrower execute loan
    /// borrower repay loan
    function testIntegration2() public {
        // borrower request loan
        // uint256 borrowAmount = 1000 * (10 ** token1.decimals());
        // uint256 loanId = _requestLoan(
        //     borrower1,
        //     address(token1),
        //     borrowAmount,
        //     1 days
        // );
        // uint256 termId1 = _registerAndCreateTerm(lender1, 500);
        // uint256 termId2 = _registerAndCreateTerm(lender2, 1000);
        // _depositAndDelegate(depositor1, 1000, 1000, address(token1), termId1);
        // _depositAndDelegate(depositor2, 1000, 1000, address(token1), termId2);
        // _allocateTermAndFundOnLoan(
        //     lender1,
        //     address(token1),
        //     loanId,
        //     termId1,
        //     500
        // );
        // _allocateTermAndFundOnLoan(
        //     lender2,
        //     address(token1),
        //     loanId,
        //     termId2,
        //     500
        // );
        // // borrower execute loan
        // vm.prank(borrower1);
        // loanManager.executeLoan(loanId);
        // // mint 5% interest to borrower to pay extra
        // uint256 interest = (borrowAmount * 500) / 10000;
        // token1.mint(borrower1, interest);
        // // borrower repay loan
        // vm.startPrank(borrower1);
        // token1.approve(address(assetManager), borrowAmount + interest);
        // loanManager.repay(loanId);
        // vm.stopPrank();
    }

    // todo: think some better file structure to prevent duplicate here and loanmanager.t.sol
    // -----------------------------------------
    // ----------- UTILS FUNCTIONS -------------
    // -----------------------------------------
    function _requestLoan(
        address borrower,
        address token,
        uint256 borrowAmount,
        uint256 delay
    ) private returns (uint256) {
        vm.startPrank(borrower);
        uint256 loanId = loanManager.requestLoan(
            address(token),
            borrowAmount,
            block.timestamp + delay
        );
        vm.stopPrank();
        return loanId;
    }

    function _registerAndCreateTerm(
        address lender,
        uint96 commission
    ) private returns (uint256) {
        vm.startPrank(lender);
        lendingManager.register();
        uint256 termId = lendingManager.createLendingTerm(commission);
        vm.stopPrank();
        return termId;
    }

    function _depositAndDelegate(
        address depositor,
        uint256 depositAmount,
        uint256 delegateAmount,
        address token,
        uint256 termId
    ) private {
        ERC20Mock mockToken = ERC20Mock(token);
        vm.startPrank(depositor);
        // deposit some token to vault by asset manager
        uint256 depositAmountWithDecimals = depositAmount *
            (10 ** mockToken.decimals());
        token1.approve(address(assetManager), depositAmountWithDecimals);
        assetManager.deposit(address(token), depositAmountWithDecimals);

        uint256 delegateAmountWithDecimals = delegateAmount *
            (10 ** mockToken.decimals());

        uint256 delegateAmountWithSharesDecimals = assetManager.convertToShares(
            token,
            delegateAmountWithDecimals
        );
        // delegate shares to lender1
        lendingManager.depositToTerm(
            termId,
            address(token),
            delegateAmountWithSharesDecimals
        );
        vm.stopPrank();
    }

    function _allocateTermAndFundOnLoan(
        address lender,
        address token,
        uint256 loanId,
        uint256 termId,
        uint256 allocateAmount
    ) private {
        vm.startPrank(lender);
        // allocate term
        loanManager.allocateTerm(loanId, termId);
        ERC20Mock mockToken = ERC20Mock(token);
        uint256 allocateFundOnTermAmount = allocateAmount *
            (10 ** mockToken.decimals());
        loanManager.allocateFundOnLoan(
            loanId,
            termId,
            allocateFundOnTermAmount
        );
        vm.stopPrank();
    }
}
