pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Hooks Interface
interface IHooks {
    function beforeDepositToTerm(address sender) external returns (bool);
}
