pragma solidity ^0.8.21;

import {IDepositWithdraw} from "./interfaces/IDepositWithdraw.sol";
import {IGovernable} from "./interfaces/IGovernable.sol";
import {ITweakedERC4626} from "./interfaces/ITweakedERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @author Quantum3 Labs
/// @title Stormbit Asset Manager
/// @notice entrypoint for all asset management operations

contract StormbitAssetManager is
    IDepositWithdraw,
    IGovernable,
    ITweakedERC4626
{
    using Math for uint256;
    address private _governor;

    mapping(address => bool) tokens;
    mapping(address => uint256) totalShares;
    mapping(address => mapping(address => uint256)) userShares;

    uint256 public constant SHARE_DECIMAL_OFFSET = 8;

    constructor(address governor) {
        _governor = governor;
    }

    modifier onlyGovernor() {
        require(msg.sender == _governor, "StormbitAssetManager: not governor");
        _;
    }

    function deposit(
        address token,
        uint256 assets
    ) public override returns (bool) {
        require(tokens[token], "StormbitAssetManager: token not supported");
    }

    function withdraw(
        address token,
        uint256 shares
    ) public override returns (bool) {}

    function addToken(address token) public override onlyGovernor {
        tokens[token] = true;
    }

    function removeToken(address token) public override onlyGovernor {
        tokens[token] = false;
    }

    function convertToShares(
        uint256 assets
    ) public view override returns (uint256) {}

    function convertToAssets(
        uint256 shares
    ) public view override returns (uint256) {}

    function maxRedeem(address owner) public view override returns (uint256) {}

    function maxWithdraw(
        address owner
    ) public view override returns (uint256) {}

    function _convertToShares(
        address token,
        uint256 assets
    ) internal view returns (uint256) {
        uint256 _totalShares = totalShares[token];
        uint256 _totalAssets = IERC20(token).balanceOf(address(this));
        return
            assets.mulDiv(
                _totalShares + 10 ** SHARE_DECIMAL_OFFSET,
                _totalAssets,
                Math.Rounding.Floor
            );
    }

    function _convertToAssets(
        address token,
        uint256 shares
    ) internal view returns (uint256) {
        uint256 _totalShares = totalShares[token];
        uint256 _totalAssets = IERC20(token).balanceOf(address(this));
        return
            shares.mulDiv(
                _totalAssets + 1,
                _totalShares + 10 ** SHARE_DECIMAL_OFFSET,
                Math.Rounding.Floor
            );
    }
}
