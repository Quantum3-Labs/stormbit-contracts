// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IHooks} from "../../src/interfaces/hooks/IHooks.sol";

contract MockHooks is IHooks {
    bool public beforeDepositToTermCalled;

    function beforeDepositToTerm(address sender, address token, uint256 termId, uint256 shares)
        external
        override
        returns (bool)
    {
        beforeDepositToTermCalled = true;
        return true;
    }
}
