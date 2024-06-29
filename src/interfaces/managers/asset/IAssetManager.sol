// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Asset Manager Interface
/// TODO split into different interfaces according to funcionality
interface IAssetManager {
    event AddToken(address indexed token, address indexed vault);

    event RemoveToken(address indexed token, address indexed vault);

    event Deposit(address indexed user, address indexed token, uint256 assets);

    /// @dev note that withdraw event uses assets instead of shares
    event Withdraw(
        address indexed user,
        address indexed vaultToken,
        uint256 assets,
        uint256 sharesBurned
    );

    event BorrowerWithdraw(
        address indexed borrower,
        address indexed token,
        uint256 shares
    );

    function addToken(address _asset) external;

    function removeToken(address _asset) external;

    function isTokenSupported(address token) external view returns (bool);

    function getVaultToken(address token) external view returns (address);

    function getUserShares(
        address token,
        address user
    ) external view returns (uint256);

    function convertToShares(
        address token,
        uint256 assets
    ) external view returns (uint256);

    function convertToAssets(
        address token,
        uint256 shares
    ) external view returns (uint256);

    function deposit(address token, uint256 assets) external;

    function depositFrom(
        address token,
        uint256 assets,
        address depositor,
        address receiver
    ) external;

    function withdraw(address token, uint256 shares) external;

    function borrowerWithdraw(
        address borrower,
        address token,
        uint256 assets
    ) external;
}
