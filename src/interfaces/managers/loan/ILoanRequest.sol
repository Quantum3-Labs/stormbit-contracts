pragma solidity ^0.8.21;

import {ILendingTerms} from "../lending/ILendingTerms.sol";

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
        uint256 repayAmount;
        uint256 sharesRequired;
        uint256 sharesAllocated;
        uint256 deadline;
        LoanStatus status;
    }

    event LoanRequested(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed token,
        uint256 amount
    );

    function requestLoan(
        address token,
        uint256 amount,
        uint256 deadline
    ) external returns (uint256);
}
