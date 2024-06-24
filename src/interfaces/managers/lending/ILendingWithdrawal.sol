pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Lending Terms Interface
/// TODO split into different interfaces according to funcionality
interface ILendingWithdrawal {
    event LenderClaimLoanProfit(uint256 indexed termId, uint256 indexed loanId, address indexed token, uint256 profit);

    event BorrowerWithdraw(address indexed borrower, address indexed token, uint256 shares);

    function borrowerWithdraw(address borrower, address token, uint256 shares) external;

    function lenderClaimLoanProfit(uint256 termId, uint256 loanId, address token) external;
}
