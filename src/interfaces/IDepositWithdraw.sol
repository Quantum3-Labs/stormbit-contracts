pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Deposit & withdraw Interface
/// TODO split into different interfaces according to funcionality
interface IDepositWithdraw {
    function deposit(address token, uint256 assets) external returns (bool);

    function withdraw(address token, uint256 shares) external returns (bool);
}
