pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager Interface
/// TODO split into different interfaces according to funcionality
interface ILoanManager {
    event LoanExecuted(uint256 indexed loanId, address indexed borrower, address indexed token, uint256 repayAssets);

    event LoanRepaid(uint256 indexed loanId, address indexed repayUser);

    function executeLoan(uint256 loanId) external;

    function repay(uint256 loanId) external;
}
