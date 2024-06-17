pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Allocation Interface
/// TODO split into different interfaces according to funcionality
interface IAllocation {
    event TermAllocated(uint256 indexed loanId, uint256 indexed termId);

    event AllocatedFundOnLoan(
        uint256 indexed loanId,
        uint256 indexed termId,
        uint256 amount
    );

    function allocateTerm(uint256 loanId, uint256 termId) external;

    function allocateFundOnLoan(
        uint256 loanId,
        uint256 termId,
        uint256 amount
    ) external;
}
