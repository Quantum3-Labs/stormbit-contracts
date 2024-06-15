pragma solidity ^0.8.21;

import {IAllocation} from "./IAllocation.sol";
import {ILoanRequest} from "./ILoanRequest.sol";

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager Getter Functions Interface
/// TODO split into different interfaces according to funcionality
interface ILoanManagerView {
    function getLoanParticipator(
        uint256 loanId,
        address depositor
    ) external view returns (IAllocation.LoanParticipator memory);

    function getLoan(
        uint256 loanId
    ) external view returns (ILoanRequest.Loan memory);

    function getLoanTermAllocated(
        uint256 loanId,
        uint256 termId
    ) external view returns (bool);
}
