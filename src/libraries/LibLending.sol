// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibAppStorage, AppStorage, PoolStorage} from "../libraries/LibAppStorage.sol";
import {Errors, Events} from "../libraries/Common.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// TODO : remove msg.sender from all functions here, pass as function argument
library LibLending {
    using Math for uint256;

    function _deposit(uint256 poolId, uint256 assets) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        address assetVault = ps.assetVault;
        address asset = IERC4626(assetVault).asset();

        if (assetVault == address(0)) {
            revert Errors.InvalidPool();
        }

        // update pool shares in stormbit
        uint256 poolShares = _convertToPoolShares(assetVault, assets);
        IERC20(asset).transferFrom(msg.sender, address(this), assets);
        IERC20(asset).approve(assetVault, assets);
        IERC4626(assetVault).deposit(assets, address(this));
        s.totalShares += poolShares;
        s.poolShare[poolId] += poolShares;

        // update user shares in pool
        uint256 userShares = _convertToUserShares(poolId, poolShares);
        ps.totalShares += userShares;
        ps.userShare[msg.sender] += userShares;

        emit Events.PoolDeposit(poolId, msg.sender, asset, assets);
    }

    // shares in the pool
    function _withdraw(uint256 poolId, uint256 shares) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        address assetVault = ps.assetVault;
        address asset = IERC4626(assetVault).asset();
        if (assetVault == address(0)) {
            revert Errors.InvalidPool();
        }

        uint256 poolShares = _convertToUserAssets(poolId, shares);

        uint256 assetsToRedeem = _convertToPoolAssets(assetVault, poolShares);

        uint256 sharesToRedeem = IERC4626(assetVault).convertToShares(
            assetsToRedeem
        );
        uint256 assetsRedeemed = IERC4626(assetVault).redeem(
            sharesToRedeem,
            msg.sender,
            address(this)
        );

        s.poolShare[poolId] -= poolShares;
        ps.userShare[msg.sender] -= shares;
        ps.totalShares -= shares;
        s.totalShares -= poolShares;

        emit Events.PoolWithdraw(poolId, msg.sender, asset, assetsRedeemed);
    }

    function _totalShares(uint256 poolId) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        return ps.totalShares;
    }

    // TODO : use transient storage for this logic to reduce gas
    // returns how much shares the pool has in the protocol
    function _convertToPoolShares(
        address assetVault,
        uint256 assets
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 totalAssets = _totalStormbitAssets(assetVault);
        return
            assets.mulDiv(
                s.totalShares + 10 ** _decimalsOffset(),
                totalAssets + 1,
                Math.Rounding.Floor
            );
    }

    function _totalStormbitAssets(
        address assetVault
    ) internal view returns (uint256) {
        uint256 totalShares = IERC4626(assetVault).balanceOf(address(this));
        return IERC4626(assetVault).previewRedeem(totalShares);
    }

    function _convertToUserShares(
        uint256 poolId,
        uint256 assets
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        uint256 stormbitShares = s.poolShare[poolId];

        return
            assets.mulDiv(
                ps.totalShares + 10 ** _decimalsOffset(),
                stormbitShares + 1,
                Math.Rounding.Floor
            );
    }

    function _convertToUserAssets(
        uint256 poolId,
        uint256 shares
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        PoolStorage storage ps = s.pools[poolId];
        uint256 poolShares = s.poolShare[poolId];
        return
            shares.mulDiv(poolShares + 1, ps.totalShares, Math.Rounding.Ceil);
    }

    function _convertToPoolAssets(
        address assetVault,
        uint256 assets
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 totalAssets = _totalStormbitAssets(assetVault);
        return
            assets.mulDiv(
                totalAssets + 1,
                s.totalShares + 10 ** _decimalsOffset(),
                Math.Rounding.Ceil
            );
    }

    // TODO: check if this is the correct decimal offset
    function _decimalsOffset() internal pure returns (uint8) {
        return 8;
    }
}
