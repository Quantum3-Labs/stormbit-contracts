// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Asset Manager Getter Functions Interface
/// TODO split into different interfaces according to funcionality
interface IAssetManagerView {
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
}
