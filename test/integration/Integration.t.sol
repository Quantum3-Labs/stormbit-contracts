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
    /// 1 depositors, 1 term, 1 lender, 1 borrower
    /// borrower borrow 1000 token1
    /// lender create a term with 10% commission
    /// depositor1 deposit 1000 token1 and delegate 1000 to lender1
    /// lender allocate term with 10% commission to loan
    /// lender allocate 1000 shares to loan
    /// borrower execute loan
    /// borrower repay loan
    function testIntegration1() public {
        uint256 borrowAmount = 1000 * (10 ** token1.decimals());
        uint256 loanId = _requestLoan(borrower1, address(token1), borrowAmount, 1 days);
        // 5% interest rate
        ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
        uint256 expectedRepayAmount = borrowAmount + (borrowAmount * 5) / 100;
        assert(loan.borrower == borrower1);
        assert(loan.token == address(token1));
        assert(loan.repayAmount == expectedRepayAmount);

        // lender take 10% commission on profit
        uint256 termId = _registerAndCreateTerm(lender1, 1000);

        IERC4626 vaultTokenInterface = IERC4626(assetManager.getVaultToken(address(token1)));
        _depositAndDelegate(depositor1, 1000, 1000, address(token1), termId);
        // check balance of depositor1 and lending manager
        uint256 depositor1SharesBalanceReal = vaultTokenInterface.balanceOf(depositor1);
        uint256 depositor1SharesBalanceBeforeDeposit = 1000 * (10 ** vaultTokenInterface.decimals());
        uint256 depositedShares = 1000 * (10 ** vaultTokenInterface.decimals());

        uint256 lendingManagerSharesBalance = vaultTokenInterface.balanceOf(address(lendingManager));

        assert(lendingManagerSharesBalance == depositedShares);
        assert(depositor1SharesBalanceReal == depositor1SharesBalanceBeforeDeposit - depositedShares);

        // check user total delegated shares on lending manager
        uint256 depositor1TotalDelegatedShares = lendingManager.getUserTotalDelegatedShares(depositor1, address(token1));
        assert(depositor1TotalDelegatedShares == depositedShares);
        // check delegated shares on term
        uint256 termDelegatedShares = lendingManager.getDisposableSharesOnTerm(termId, address(token1));
        assert(termDelegatedShares == depositedShares);
        // check term total and disposable shares
        uint256 termTotalShares = lendingManager.getTotalSharesOnTerm(termId, address(token1));
        assert(termTotalShares == depositedShares);

        _allocateTermAndFundOnLoan(lender1, address(token1), loanId, termId, 1000);

        // check term allocated counter
        uint256 termAllocatedCounter = loanManager.getTermLoanAllocatedCounter(termId);
        assert(termAllocatedCounter == 1);

        // check if term allocated to loan
        bool termAllocatedToLoan = loanManager.getLoanTermAllocated(loanId, termId);
        assert(termAllocatedToLoan == true);

        // check freezed shares on term
        uint256 termFreezedShares = lendingManager.getTermFreezedShares(termId, address(token1));
        uint256 expectedTermFreezedShares = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(termFreezedShares == expectedTermFreezedShares);

        // check loan allocated shares
        // get loan
        loan = loanManager.getLoan(loanId);
        uint256 expectedLoanAllocatedShares = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(loan.sharesAllocated == expectedLoanAllocatedShares);

        // borrower1 asset balance beofre loan
        uint256 borrower1BalanceBeforeLoan = token1.balanceOf(borrower1);
        // borrower execute loan
        vm.startPrank(borrower1);
        // pass time
        skip(1 days);
        loanManager.executeLoan(loanId);
        vm.stopPrank();

        // check loan status
        loan = loanManager.getLoan(loanId);
        assert(loan.status == ILoanRequest.LoanStatus.Active);

        // check borrower asset balance
        uint256 borrower1Balance = token1.balanceOf(borrower1);
        assert(borrower1BalanceBeforeLoan == 0);
        assert(borrower1Balance == borrowAmount);

        // check lending manager shares balance
        uint256 lendingManagerBalance = vaultTokenInterface.balanceOf(address(lendingManager));
        assert(lendingManagerBalance == 0);

        // repay loan
        // mint 5% interest to borrower to pay extra
        uint256 interest = (borrowAmount * 5) / 100;
        token1.mint(borrower1, interest);
        // borrower repay loan
        vm.startPrank(borrower1);
        token1.approve(address(assetManager), borrowAmount + interest);
        loanManager.repay(loanId);
        vm.stopPrank();

        // check loan status
        loan = loanManager.getLoan(loanId);
        assert(loan.status == ILoanRequest.LoanStatus.Repaid);

        // check borrower balance
        borrower1Balance = token1.balanceOf(borrower1);
        assert(borrower1Balance == 0);

        // check lending manager shares balance
        lendingManagerBalance = vaultTokenInterface.balanceOf(address(lendingManager));
        // convert repay amount to shares
        uint256 expectedLendingManagerShares = assetManager.convertToShares(address(token1), borrowAmount + interest);
        assert(lendingManagerBalance == expectedLendingManagerShares);

        // term owner claim loan profit
        vm.startPrank(lender1);
        lendingManager.lenderClaimLoanProfit(termId, loanId, address(token1));
        vm.stopPrank();

        // check term owner balance
        // calculate repay amount in shares
        uint256 repayAmountInShares = assetManager.convertToShares(address(token1), loan.repayAmount);
        uint256 profitShares = repayAmountInShares - loan.sharesRequired;
        uint256 lender1Balance = vaultTokenInterface.balanceOf(lender1);
        // 10% commission on profit
        uint256 expectedLender1Balance = (profitShares * 10) / 100;
        assert(lender1Balance == expectedLender1Balance);

        // calculate remaining profit shares
        uint256 remainingProfitShares = profitShares - expectedLender1Balance;
        // check term profit
        uint256 termProfit = lendingManager.getTermProfit(termId, address(token1));
        assert(termProfit == remainingProfitShares);

        // check disposable amount is equal to initial deposit amount
        uint256 disposableAmount = lendingManager.getDisposableSharesOnTerm(termId, address(token1));
        uint256 expectedDisposableAmount = 1000 * (10 ** vaultTokenInterface.decimals());
        assert(disposableAmount == expectedDisposableAmount);

        // check term freezed shares
        termFreezedShares = lendingManager.getTermFreezedShares(termId, address(token1));
        assert(termFreezedShares == 0);

        // depositor withdraw from term
        uint256 depositor1BalanceBeforeWithdraw = vaultTokenInterface.balanceOf(depositor1);
        vm.startPrank(depositor1);
        lendingManager.withdrawFromTerm(termId, address(token1), depositedShares);
        vm.stopPrank();

        // check term total and disposable shares
        termTotalShares = lendingManager.getTotalSharesOnTerm(termId, address(token1));
        assert(termTotalShares == 0);
        uint256 termDisposableShares = lendingManager.getDisposableSharesOnTerm(termId, address(token1));
        assert(termDisposableShares == 0);

        // check depositor1 total delegated shares and total delegated shares on term
        depositor1TotalDelegatedShares = lendingManager.getUserTotalDelegatedShares(depositor1, address(token1));
        assert(depositor1TotalDelegatedShares == 0);

        // check user shares balance, should be equal to initial balance + profit
        uint256 depositor1SharesBalance = vaultTokenInterface.balanceOf(depositor1);
        uint256 expectedDepositor1SharesBalance =
            depositor1BalanceBeforeWithdraw + depositedShares + remainingProfitShares;
        assert(depositor1SharesBalance == expectedDepositor1SharesBalance);
    }

    // todo: move to utils file
    // -----------------------------------------
    // ----------- UTILS FUNCTIONS -------------
    // -----------------------------------------
    function _requestLoan(address borrower, address token, uint256 borrowAmount, uint256 delay)
        private
        returns (uint256)
    {
        vm.startPrank(borrower);
        uint256 loanId = loanManager.requestLoan(address(token), borrowAmount, block.timestamp + delay);
        vm.stopPrank();
        return loanId;
    }

    function _registerAndCreateTerm(address lender, uint96 commission) private returns (uint256) {
        vm.startPrank(lender);
        lendingManager.register();
        uint256 termId = lendingManager.createLendingTerm(commission);
        vm.stopPrank();
        return termId;
    }

    function _depositAndDelegate(
        address depositor,
        uint256 depositAssets,
        uint256 delegateShares,
        address token,
        uint256 termId
    ) private {
        ERC20Mock mockToken = ERC20Mock(token);
        vm.startPrank(depositor);
        // deposit some token to vault by asset manager
        uint256 depositAssetsWithDecimals = depositAssets * (10 ** mockToken.decimals());
        mockToken.approve(address(assetManager), depositAssetsWithDecimals);
        assetManager.deposit(address(token), depositAssetsWithDecimals);

        address vaultToken = assetManager.getVaultToken(token);
        IERC4626 vaultTokenInterface = IERC4626(vaultToken);
        uint256 delegateSharesWithDecimals = delegateShares * (10 ** vaultTokenInterface.decimals());

        // approve lending manager to transfer depositor delegate amount from depisitor to lending manager
        vaultTokenInterface.approve(address(lendingManager), delegateSharesWithDecimals);
        // delegate shares to lender1
        lendingManager.depositToTerm(termId, address(token), delegateSharesWithDecimals);
        vm.stopPrank();
    }

    function _allocateTermAndFundOnLoan(
        address lender,
        address token,
        uint256 loanId,
        uint256 termId,
        uint256 allocateAssets
    ) private {
        vm.startPrank(lender);
        // allocate term
        loanManager.allocateTerm(loanId, termId);
        ERC20Mock mockToken = ERC20Mock(token);
        uint256 allocateFundOnTermAssets = allocateAssets * (10 ** mockToken.decimals());
        loanManager.allocateFundOnLoan(loanId, termId, allocateFundOnTermAssets);
        vm.stopPrank();
    }
}
