pragma solidity ^0.8.21;

import {ILendingTerms} from "./ILendingTerms.sol";

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager Interface
/// TODO split into different interfaces according to funcionality
interface ILoanRequest {
    enum LoanStatus {
        Pending,
        Active,
        Repaid,
        Cancelled
    }

    struct Loan {
        address borrower;
        address token;
        uint256 amount;
        uint256 currentAllocated;
        uint256 deadline;
        ILendingTerms.LendingTerm[] terms;
        LoanStatus status;
    }

    event LoanRequested(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed token,
        uint256 amount,
        uint256 deadline
    );

    function requestLoan(
        address token,
        uint256 amount,
        uint256 deadline
    ) external returns (uint256);

    function executeLoan(uint256 loanId) external;

    function repay(uint256 loanId) external;
}
