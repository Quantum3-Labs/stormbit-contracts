pragma solidity ^0.8.21;

import {Hooks} from "../libraries/Hooks.sol";
import {BaseHook} from "./BaseHook.sol";
import {StormbitLendingManager} from "../LendingManager.sol";

contract WhiteList is BaseHook {
    mapping(address user => bool isWhiteListed) private whitelist;

    constructor(
        StormbitLendingManager _manager,
        address[] memory whiteListedAddrs
    ) BaseHook(_manager) {
        for (uint256 i = 0; i < whiteListedAddrs.length; i++) {
            whitelist[whiteListedAddrs[i]] = true;
        }
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return Hooks.Permissions({beforeDepositToTerm: true});
    }

    function beforeDepositToTerm(
        address sender
    ) external override onlyByManager returns (bool) {
        require(whitelist[sender], "WhiteList: not whitelisted");
        return true;
    }

    function addWhiteList(address user) external {
        whitelist[user] = true;
    }
}
