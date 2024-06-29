pragma solidity ^0.8.21;

import {ILendingTerms} from "./ILendingTerms.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager Getter Functions Interface
/// TODO split into different interfaces according to funcionality
interface ILendingManagerView {
    function getLendingTerm(uint256 id) external returns (ILendingTerms.LendingTerm memory);

    function getTermFreezedShares(uint256 termId, address token) external view returns (uint256);

    function getTermProfit(uint256 termId, address token) external returns (uint256);

    function getUserTotalDelegatedShares(address user, address token) external view returns (uint256);
}
