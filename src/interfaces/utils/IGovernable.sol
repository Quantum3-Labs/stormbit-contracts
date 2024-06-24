pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Admin Interface
/// TODO split into different interfaces according to funcionality
interface IGovernable {
    function governor() external view returns (address);
}
