// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibAppStorage, AppStorage, PoolStorage} from "../libraries/LibAppStorage.sol";
import {Errors, Events} from "../libraries/Common.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library LibLending {
    using Math for uint256;

    function _deposit(uint256 poolId, uint256 amount, address token) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        if (s.supportedAssets[token] == false) {
            revert Errors.TokenNotSupported(token);
        }
        // get shares
        uint256 shares = _convertToShares(poolId, amount, token, Math.Rounding.Floor);
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        s.balances[poolId][token] += amount;
        ps.balances[msg.sender][token] += shares;
        ps.totalShares += shares;

        emit Events.PoolDeposit(poolId, msg.sender, token, amount);
    }

    function _withdraw(uint256 poolId, uint256 amount, address token) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];

        uint256 shares = _convertToShares(poolId, amount, token, Math.Rounding.Ceil);
        if (s.supportedAssets[token] == false) {
            revert Errors.TokenNotSupported(token);
        }
        if (ps.balances[msg.sender][token] < shares) {
            revert Errors.InsuficientBalance(shares);
        }

        IERC20(token).transfer(msg.sender, amount);
        s.balances[poolId][token] -= amount;
        ps.balances[msg.sender][token] -= shares;
        ps.totalShares -= shares;

        emit Events.PoolWithdraw(poolId, msg.sender, token, amount);
    }

    function _convertToShares(uint256 poolId, uint256 amount, address token, Math.Rounding rounding)
        internal
        returns (uint256)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        uint256 underlyingBalance = s.balances[poolId][token];
        return amount.mulDiv(ps.totalShares + 10 ** 18, underlyingBalance + 1, rounding);
    }
}
