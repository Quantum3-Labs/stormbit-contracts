pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager Interface
/// TODO split into different interfaces according to funcionality
interface ILoanManager {
    enum LoanStatus {
        Pending,
        Active,
        Repaid,
        Cancelled
    }

    struct Loan {
        address borrower;
        address token;
        uint256 repayAssets;
        uint256 sharesRequired;
        uint256 sharesAllocated;
        uint256 deadlineAllocate;
        LoanStatus status;
    }

    event LoanRequested(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed token,
        uint256 assets
    );

    event TermAllocated(uint256 indexed loanId, uint256 indexed termId);

    event AllocatedFundOnLoan(
        uint256 indexed loanId,
        uint256 indexed termId,
        uint256 assets
    );

    event LoanExecuted(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed token,
        uint256 repayAssets
    );

    event LoanRepaid(uint256 indexed loanId, address indexed repayUser);

    function requestLoan(
        address token,
        uint256 assets,
        uint256 deadline
    ) external returns (uint256);
    function getLoan(uint256 loanId) external view returns (Loan memory);

    function getLoanTermAllocated(
        uint256 loanId,
        uint256 termId
    ) external view returns (bool);

    function getTermLoanAllocatedCounter(
        uint256 termId
    ) external view returns (uint256);

    function getTermAllocatedSharesOnLoan(
        uint256 loanId,
        uint256 termId,
        address token
    ) external view returns (uint256);

    function allocateTerm(uint256 loanId, uint256 termId) external;

    function allocateFundOnLoan(
        uint256 loanId,
        uint256 termId,
        uint256 assets
    ) external;

    function executeLoan(uint256 loanId) external;

    function repay(uint256 loanId) external;
}
