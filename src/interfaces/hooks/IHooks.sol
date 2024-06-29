pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Hooks Interface
interface IHooks {
    function beforeDepositToTerm(address from, address token, uint256 termId, uint256 shares) external returns (bool);
}
