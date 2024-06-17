pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Lending Terms Interface
/// TODO split into different interfaces according to funcionality
interface ILendingWithdrawal {
    function borrowerWithdraw(
        address borrower,
        address vaultToken,
        uint256 shares
    ) external;

    function claimLoanProfit(
        uint256 termId,
        uint256 loanId,
        address vaultToken
    ) external;
}
