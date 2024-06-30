// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IHooks} from "../../hooks/IHooks.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Terms Interface
/// TODO split into different interfaces according to funcionality
interface ILendingTerms {
    struct LendingTerm {
        address owner;
        uint256 comission; // TODO add balances and other ERC4626 custom fields
        uint256 balances;
        IHooks hooks;
    }

    event LendingTermCreated(uint256 indexed id, address lender, uint256 comission);
    event LendingTermRemoved(uint256 indexed id);

    function createLendingTerm(uint256 comission, IHooks hooks) external returns (uint256);

    function removeLendingTerm(uint256 id) external;
}
