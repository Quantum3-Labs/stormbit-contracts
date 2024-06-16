pragma solidity ^0.8.21;

import {ILendingTerms} from "./ILendingTerms.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager Getter Functions Interface
/// TODO split into different interfaces according to funcionality
interface ILendingManagerView {
    function getLendingTerm(
        uint256 id
    ) external returns (ILendingTerms.LendingTerm memory);

    function getDisposableSharesOnTerm(
        uint256 termId,
        address vaultToken
    ) external view returns (uint256);

    function getTermDepositors(
        uint256 termId,
        address vaultToken
    ) external view returns (address[] memory);

    function getUserDisposableSharesOnTerm(
        uint256 termId,
        address user,
        address vaultToken
    ) external view returns (uint256);

    function getUserFreezedShares(
        address user,
        address vaultToken
    ) external view returns (uint256);

    function getUserTotalDelegatedShares(
        address user,
        address vaultToken
    ) external view returns (uint256);
}
