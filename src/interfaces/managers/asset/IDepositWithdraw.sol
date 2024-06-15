pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Deposit & withdraw Interface
/// TODO split into different interfaces according to funcionality
interface IDepositWithdraw {
    event Deposit(address indexed user, address indexed token, uint256 assets);

    /// @dev note that withdraw event uses assets instead of shares
    event Withdraw(address indexed user, address indexed token, uint256 assets);

    event BorrowerWithdraw(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed tokenVault,
        address[] loanParticipators
    );

    function deposit(address token, uint256 assets) external;

    function depositFrom(
        address token,
        uint256 assets,
        address depositor,
        address receiver
    ) external;

    function withdraw(address token, uint256 shares) external;

    function borrowerWithdraw(
        uint256 loanId,
        address borrower,
        address tokenVault,
        address[] calldata loanParticipators
    ) external;
}
