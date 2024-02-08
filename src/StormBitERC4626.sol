// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// an ERC4626 with an underlying asset and with a fee for each deposit, fee is credited to StormBit Core

contract StormBitERC4626 is ERC4626 {
    IERC20 private _underlyingToken;

    constructor(IERC20 underlyingToken) ERC4626(underlyingToken) ERC20("StormBit", "STB") {
        _underlyingToken = underlyingToken;
        _mint(msg.sender, 10000000);
    }

    // UNDERLYING TOKEN
    function asset() public view override returns (address) {
        return address(_underlyingToken);
    }

    /**
     * @inheritdoc ERC4626s
     */

    function totalAssets() public view override returns (uint256) {
        assembly {
            if eq(sload(0), 2) {
                mstore(0x00, 0xed3ba6a6)
                revert(0x1c, 0x04)
            }
        }
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }
        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    /**
     * @inheritdoc ERC4626
     */
    function beforeWithdraw(uint256 assets, uint256 shares) internal override nonReentrant {}

    /**
     * @inheritdoc ERC4626
     */
    function afterDeposit(uint256 assets, uint256 shares) internal override nonReentrant {}
}
