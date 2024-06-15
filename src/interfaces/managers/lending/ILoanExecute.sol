pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager Interface
/// TODO split into different interfaces according to funcionality
interface ILoanExecute {
    function freezeSharesOnTerm(
        uint256 termId,
        address vaultToken,
        address depositor,
        uint256 freezeAmount
    ) external;
}
