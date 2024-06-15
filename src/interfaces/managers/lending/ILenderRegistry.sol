pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Lending Registru Interface
/// TODO split into different interfaces according to funcionality
interface ILenderRegistry {
    function register() external;

    function isRegistered(address lender) external view returns (bool);
}
