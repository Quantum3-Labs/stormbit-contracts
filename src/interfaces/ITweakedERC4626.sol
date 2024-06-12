pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit custom ERC4626 Interface
/// TODO lets tweak this interface to something that suits us better
interface ITweakedERC4626 {
    function convertToShares(uint256 assets) external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function maxRedeem(address owner) external view returns (uint256);

    function maxWithdraw(address owner) external view returns (uint256);
}
