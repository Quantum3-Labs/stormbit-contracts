// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibAppStorage, AppStorage, PoolStorage} from "../libraries/LibAppStorage.sol";
import {Errors} from "../libraries/Common.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LibLending {
    function _deposit(uint256 poolId, uint256 amount, address token) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        if (s.supportedAssets[token] == false) {
            revert Errors.TokenNotSupported(token);
        }
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        s.balances[poolId][token] += amount;
        ps.balances[msg.sender][token] += amount;
    }
}
