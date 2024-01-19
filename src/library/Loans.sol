// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

library Loans {
    using Loans for Loans.Lender;

    struct Lender {
        address tokensStaked;
        uint256 tokensVotingAllocation; // tokens allocated for voting
        uint256 tokensLocked;
        uint256 tokensLockedUntil;
    }
}
