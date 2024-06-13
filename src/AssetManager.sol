pragma solidity ^0.8.21;

import {IDepositWithdraw} from "./interfaces/IDepositWithdraw.sol";
import {IGovernable} from "./interfaces/IGovernable.sol";
import {IAssetManager} from "./interfaces/IAssetManager.sol";
import {BaseVault} from "./vaults/BaseVault.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @author Quantum3 Labs
/// @title Stormbit Asset Manager
/// @notice entrypoint for all asset management operations

contract StormbitAssetManager is IDepositWithdraw, IGovernable, IAssetManager {
    using Math for uint256;
    address private _governor;

    mapping(address => bool) tokens; // check if token is supported
    mapping(address => address) tokenVaults; // token to vault mapping
    mapping(address => uint256) totalShares; // total shares of a token
    mapping(address => mapping(address => uint256)) userShares; // user shares of a token

    uint256 public constant SHARE_DECIMAL_OFFSET = 8;

    constructor(address initialGovernor) {
        _governor = initialGovernor;
    }

    modifier onlyGovernor() {
        require(msg.sender == _governor, "StormbitAssetManager: not governor");
        _;
    }

    /// @dev allow depositor deposit assets to the vault
    /// @param token address of the token
    /// @param assets amount of assets to deposit
    function deposit(address token, uint256 assets) public override {
        require(tokens[token], "StormbitAssetManager: token not supported");
        address tokenVault = tokenVaults[token]; // get the corresponding vault
        IERC20(token).approve(tokenVault, assets);
        IERC4626(tokenVault).deposit(assets, msg.sender);
        emit Deposit(msg.sender, token, assets);
    }

    /// @dev note that we dont require the token to be whitelisted
    function withdraw(address token, uint256 shares) public override {
        // emit Withdraw(msg.sender, token, assets);
    }

    /// @dev allow governor to add a new token
    /// @param token address of the token
    function addToken(address token) public onlyGovernor {
        if (tokens[token]) return;
        tokens[token] = true;
        // deploy the vault
        BaseVault vault = new BaseVault(
            IERC20(token),
            _governor,
            string(abi.encodePacked("Stormbit ", IERC20(token).symbol())),
            string(abi.encodePacked("s", IERC20(token).symbol()))
        );
        // update the mapping
        tokenVaults[token] = address(vault);
    }

    function removeToken(address token) public override onlyGovernor {
        tokens[token] = false;
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------

    function governor() public view override returns (address) {
        return _governor;
    }

    function isTokenSupported(address token) public view returns (bool) {
        return tokens[token];
    }

    /// @dev get token vault address
    function getTokenVault(address token) public view returns (address) {
        return tokenVaults[token];
    }

    /// @dev get user shares on specific vault
    function getUserShares(
        address token,
        address user
    ) public view returns (uint256) {
        address tokenVault = tokenVaults[token];
        IERC4626 vault = IERC4626(tokenVault);
        return vault.balanceOf(user);
    }
}
