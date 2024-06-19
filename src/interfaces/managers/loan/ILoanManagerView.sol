pragma solidity ^0.8.21;

import {IAllocation} from "./IAllocation.sol";
import {ILoanRequest} from "./ILoanRequest.sol";

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager Getter Functions Interface
/// TODO split into different interfaces according to funcionality
interface ILoanManagerView {
    function getLoan(uint256 loanId) external view returns (ILoanRequest.Loan memory);

    function getLoanTermAllocated(uint256 loanId, uint256 termId) external view returns (bool);

    function getTermLoanAllocatedCounter(uint256 termId) external view returns (uint256);

    function getTermAllocatedSharesOnLoan(uint256 loanId, uint256 termId, address vaultToken)
        external
        view
        returns (uint256);
}
