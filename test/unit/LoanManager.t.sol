// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {SetupTest} from "../Setup.t.sol";
import {ILoanRequest} from "../../src/interfaces/managers/loan/ILoanRequest.sol";
import {BaseVault} from "../../src/vaults/BaseVault.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract LoanManagerTest is SetupTest {
// function testRequestLoan() public {
//     uint256 borrowAmount = 500 * (10 ** token1.decimals());
//     uint256 loanId = _requestLoan(
//         borrower1,
//         address(token1),
//         borrowAmount,
//         1 days
//     );
//     ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
//     // borrow amount + 5%
//     uint256 repayAmount = borrowAmount + (borrowAmount * 5) / 100;
//     assert(loan.borrower == borrower1);
//     assert(loan.token == address(token1));
//     assert(loan.status == ILoanRequest.LoanStatus.Pending);
//     assert(loan.repayAmount == repayAmount);
//     assert(loan.sharesAllocated == 0);
//     assert(
//         loan.sharesRequired ==
//             assetManager.convertToShares(address(token1), borrowAmount)
//     );
// }
// function testAllocateTermInsufficientFundRevert() public {
//     uint256 borrowAmount = 500 * (10 ** token1.decimals());
//     uint256 loanId = _requestLoan(
//         borrower1,
//         address(token1),
//         borrowAmount,
//         1 days
//     );
//     vm.startPrank(lender1);
//     // register as lender and create lending term
//     lendingManager.register();
//     uint256 termId = lendingManager.createLendingTerm(5);
//     // allocate term, but no shares on term
//     vm.expectRevert();
//     loanManager.allocateTerm(loanId, termId);
//     vm.stopPrank();
// }
// function testAllocateTerm() public {
//     uint256 borrowAmount = 500 * (10 ** token1.decimals());
//     uint256 loanId = _requestLoan(
//         borrower1,
//         address(token1),
//         borrowAmount,
//         1 days
//     );
//     uint256 termId = _registerAndCreateTerm(lender1, 500);
//     _depositAndDelegate(depositor1, 1000, 1000, address(token1), termId);
//     vm.startPrank(lender1);
//     // allocate term
//     loanManager.allocateTerm(loanId, termId);
//     vm.stopPrank();
//     bool isAllocated = loanManager.getLoanTermAllocated(loanId, termId);
//     assert(isAllocated);
// }
// function testAllocateFundOnLoan() public {
//     uint256 borrowAmount = 500 * (10 ** token1.decimals());
//     uint256 loanId = _requestLoan(
//         borrower1,
//         address(token1),
//         borrowAmount,
//         1 days
//     );
//     uint256 termId = _registerAndCreateTerm(lender1, 500);
//     _depositAndDelegate(depositor1, 1000, 500, address(token1), termId);
//     // allocate term
//     _allocateTermAndFundOnLoan(
//         lender1,
//         address(token1),
//         loanId,
//         termId,
//         500
//     );
//     ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
//     uint256 depositor1FreezedShares = lendingManager.getUserFreezedShares(
//         depositor1,
//         address(vaultToken1)
//     );
//     uint256 depositor1DisposableShares = lendingManager
//         .getUserDisposableSharesOnTerm(
//             termId,
//             depositor1,
//             address(vaultToken1)
//         );
//     uint256 expectedAllocateFundOnTermAmount = 500 *
//         (10 ** vaultToken1.decimals());
//     assert(loan.sharesAllocated == expectedAllocateFundOnTermAmount);
//     assert(depositor1FreezedShares == expectedAllocateFundOnTermAmount);
//     assert(depositor1DisposableShares == 0);
// }
// function testExecuteLoan() public returns (uint256, uint256) {
//     uint256 borrowAmount = 500 * (10 ** token1.decimals());
//     uint256 loanId = _requestLoan(
//         borrower1,
//         address(token1),
//         borrowAmount,
//         1 days
//     );
//     uint256 termId = _registerAndCreateTerm(lender1, 500);
//     _depositAndDelegate(depositor1, 1000, 500, address(token1), termId);
//     // allocate term
//     _allocateTermAndFundOnLoan(
//         lender1,
//         address(token1),
//         loanId,
//         termId,
//         500
//     );
//     vm.startPrank(borrower1);
//     loanManager.executeLoan(loanId);
//     vm.stopPrank();
//     ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
//     uint256 depositor1Shares = assetManager.getUserShares(
//         address(token1),
//         depositor1
//     );
//     uint256 expectedDepositor1Shares = 1000 *
//         (10 ** vaultToken1.decimals()) -
//         500 *
//         (10 ** vaultToken1.decimals());
//     uint256 borrowerTokenBalance = token1.balanceOf(borrower1);
//     assert(loan.status == ILoanRequest.LoanStatus.Active);
//     assert(depositor1Shares == expectedDepositor1Shares);
//     assert(borrowerTokenBalance == borrowAmount);
//     return (loanId, termId);
// }
// function testRepayLoan() public {
//     uint256 borrowAmount = 500 * (10 ** token1.decimals());
//     uint256 loanId = _requestLoan(
//         borrower1,
//         address(token1),
//         borrowAmount,
//         1 days
//     );
//     uint256 termId = _registerAndCreateTerm(lender1, 500);
//     _depositAndDelegate(depositor1, 1000, 500, address(token1), termId);
//     // allocate term
//     _allocateTermAndFundOnLoan(
//         lender1,
//         address(token1),
//         loanId,
//         termId,
//         500
//     );
//     vm.startPrank(borrower1);
//     loanManager.executeLoan(loanId);
//     vm.stopPrank();
//     // mint the interest need to pay to borrower
//     // calculate the interest
//     uint256 interest = (borrowAmount * 500) / 10000;
//     token1.mint(borrower1, interest);
//     vm.startPrank(borrower1);
//     ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
//     token1.approve(address(assetManager), loan.repayAmount);
//     loanManager.repay(loanId);
//     vm.stopPrank();
//     // get borrower balance
//     uint256 borrowerBalance = token1.balanceOf(borrower1);
//     // get depositor1 shares
//     uint256 depositor1Shares = assetManager.getUserShares(
//         address(token1),
//         depositor1
//     );
//     // get user freezed shares
//     uint256 depositor1FreezedShares = lendingManager.getUserFreezedShares(
//         depositor1,
//         address(vaultToken1)
//     );
//     // get user disposable shares
//     uint256 depositor1DisposableShares = lendingManager
//         .getUserDisposableSharesOnTerm(
//             termId,
//             depositor1,
//             address(vaultToken1)
//         );
//     assert(borrowerBalance == 0);
//     assert(depositor1FreezedShares == 0);
//     assert(
//         depositor1DisposableShares == 500 * (10 ** vaultToken1.decimals())
//     );
//     // assert(depositor1Shares == 1000 * (10 ** vaultToken1.decimals()));
// }
// // -----------------------------------------
// // ----------- UTILS FUNCTIONS -------------
// // -----------------------------------------
// function _requestLoan(
//     address borrower,
//     address token,
//     uint256 borrowAmount,
//     uint256 delay
// ) private returns (uint256) {
//     vm.startPrank(borrower);
//     uint256 loanId = loanManager.requestLoan(
//         address(token),
//         borrowAmount,
//         block.timestamp + delay
//     );
//     vm.stopPrank();
//     return loanId;
// }
// function _registerAndCreateTerm(
//     address lender,
//     uint96 commission
// ) private returns (uint256) {
//     vm.startPrank(lender);
//     lendingManager.register();
//     uint256 termId = lendingManager.createLendingTerm(commission);
//     vm.stopPrank();
//     return termId;
// }
// function _depositAndDelegate(
//     address depositor,
//     uint256 depositAmount,
//     uint256 delegateAmount,
//     address token,
//     uint256 termId
// ) private {
//     ERC20Mock mockToken = ERC20Mock(token);
//     vm.startPrank(depositor);
//     // deposit some token to vault by asset manager
//     uint256 depositAmountWithDecimals = depositAmount *
//         (10 ** mockToken.decimals());
//     token1.approve(address(assetManager), depositAmountWithDecimals);
//     assetManager.deposit(address(token), depositAmountWithDecimals);
//     uint256 delegateAmountWithDecimals = delegateAmount *
//         (10 ** mockToken.decimals());
//     uint256 delegateAmountWithSharesDecimals = assetManager.convertToShares(
//         token,
//         delegateAmountWithDecimals
//     );
//     // delegate shares to lender1
//     lendingManager.depositToTerm(
//         termId,
//         address(token),
//         delegateAmountWithSharesDecimals
//     );
//     vm.stopPrank();
// }
// function _allocateTermAndFundOnLoan(
//     address lender,
//     address token,
//     uint256 loanId,
//     uint256 termId,
//     uint256 allocateAmount
// ) private {
//     vm.startPrank(lender);
//     // allocate term
//     loanManager.allocateTerm(loanId, termId);
//     ERC20Mock mockToken = ERC20Mock(token);
//     uint256 allocateFundOnTermAmount = allocateAmount *
//         (10 ** mockToken.decimals());
//     loanManager.allocateFundOnLoan(
//         loanId,
//         termId,
//         allocateFundOnTermAmount
//     );
//     vm.stopPrank();
// }
}
