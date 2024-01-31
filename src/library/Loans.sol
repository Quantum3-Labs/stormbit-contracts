// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

library LendingPool {
    using Loans for Loans.Lender;

    struct Lender {
        address tokensStaked;
        uint256 tokensVotingAllocation; // tokens allocated for voting
        uint256 tokensLocked;
        uint256 tokensLockedUntil;
    }

    function unlockTokens(LendingPool.Lender storage stake) internal {}

    /**
     * @dev Return all tokens withdrawable after lock period
     * @param stake Lender struct
     * @return uint256 tokensWithdrawable
     */
    function poolWithdraw(LendingPool.Lender storage stake) internal returns (uint256) {
        uint256 stakeWithdrawable = stake.tokensWithdrawable();

        if (stakeWithdrawable > 0) {
            // unlock tokens
            stake.unlockTokens(stakeWithdrawable);
            // release tokens
            stake.release(stakeWithdrawable);
        }
    }

    /**
     * @dev Return tokens available for withdrawal after lock period
     */
    function availableWithdraw(LendingPool.Lender memory stake) internal view returns (uint256) {
        if (stake.tokensLockedUntil > block.timestamp || stake.tokensLockedUntil == 0) {
            return 0;
        }
        return stake.tokensLocked;
    }
}
