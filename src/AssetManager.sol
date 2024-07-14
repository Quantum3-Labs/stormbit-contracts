// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "./interfaces/token/IERC20.sol";
import {IERC4626} from "./interfaces/token/IERC4626.sol";
import {IGovernable} from "./interfaces/utils/IGovernable.sol";
import {IInitialize} from "./interfaces/utils/IInitialize.sol";
import {BaseVault} from "./vaults/BaseVault.sol";
import {IAssetManager} from "./interfaces/managers/asset/IAssetManager.sol";
import {ILoanManager} from "./interfaces/managers/loan/ILoanManager.sol";
import {ILendingManager} from "./interfaces/managers/lending/ILendingManager.sol";

/// @author Quantum3 Labs
/// @title Stormbit Asset Manager
/// @notice entrypoint for all asset management operations

contract AssetManager is Initializable, IGovernable, IInitialize, IAssetManager {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address private _governor;
    ILoanManager public loanManager;
    ILendingManager public lendingManager;

    mapping(address token => bool isSupported) tokens; // check if token is supported
    mapping(address token => address vaultToken) vaultTokens; // token to vault mapping

    constructor(address initialGovernor) {
        _governor = initialGovernor;
    }

    // -----------------------------------------
    // -------- CUSTOM ERRORS ------------------
    // -----------------------------------------
    error NotGovernor();
    error NotLoanManager();
    error NotLendingManager();
    error TokenNotSupported();
    error TransferFailed();
    error VaultNotEmpty();

    modifier onlyGovernor() {
        if (msg.sender != _governor) revert NotGovernor();
        _;
    }

    modifier onlyLoanManager() {
        if (msg.sender != address(loanManager)) revert NotLoanManager();
        _;
    }

    modifier onlyLendingManager() {
        if (msg.sender != address(lendingManager)) {
            revert NotLendingManager();
        }
        _;
    }

    // -----------------------------------------
    // -------- PUBLIC FUNCTIONS ---------------
    // -----------------------------------------

    /// @dev used to initialize loan and lend manager address
    /// @param loanManagerAddr address of the loan manager
    /// @param lendingManagerAddr address of the lending manager
    function initialize(address loanManagerAddr, address lendingManagerAddr) public override initializer {
        loanManager = ILoanManager(loanManagerAddr);
        lendingManager = ILendingManager(lendingManagerAddr);
    }

    /// @dev allow depositor deposit assets to the vault
    /// @param token address of the token
    /// @param assets amount of assets to deposit
    function deposit(address token, uint256 assets) public override {
        _deposit(token, assets, msg.sender, msg.sender);
    }

    /// @dev same function as deposit, but allow user to deposit on behalf of another user
    function depositFrom(address token, uint256 assets, address depositor, address receiver) public override {
        _deposit(token, assets, depositor, receiver);
    }

    /// @dev note that we dont require the token to be whitelisted
    /// @dev note requires approval of `shares` equivalent of `assets` to the AssetManager from withdrawer
    function withdraw(address token, uint256 assets) public override {
        _withdraw(token, assets, msg.sender, msg.sender);
    }

    /// @dev call by lending manager, use for execute loan, redeem shares for borrower
    function withdrawTo(address receiver, address token, uint256 assets) public override {
        _withdraw(token, assets, receiver, msg.sender);
    }

    /// @dev allow governor to add a new token
    /// @param token address of the token
    function addToken(address token) public override onlyGovernor {
        if (tokens[token]) return;
        tokens[token] = true;
        // deploy the vault
        BaseVault vault = new BaseVault(
            IERC20(token),
            address(this),
            string(abi.encodePacked("Stormbit ", IERC20(token).symbol())),
            string(abi.encodePacked("s", IERC20(token).symbol()))
        );
        // update the mapping
        vaultTokens[token] = address(vault);
        emit AddToken(token, address(vault));
    }

    /// @dev allow governor to remove the support of a token
    /// @param token address of the token
    function removeToken(address token) public override onlyGovernor {
        if (!tokens[token]) {
            revert TokenNotSupported();
        }
        // get the vault address
        address vaultToken = vaultTokens[token];
        // check if vault is empty
        if (IERC4626(vaultToken).totalSupply() != 0) {
            revert VaultNotEmpty();
        }
        tokens[token] = false;

        // Remove the vault token mapping
        delete vaultTokens[token];

        emit RemoveToken(token, vaultToken);
    }

    // -----------------------------------------
    // ----------- INTERNAL FUNCTIONS ----------
    // -----------------------------------------

    function _deposit(address token, uint256 assets, address depositor, address receiver) internal {
        _checkTokenSupported(token);

        address vaultToken = vaultTokens[token];

        // Transfer tokens safely from the depositor to this contract
        IERC20(token).safeTransferFrom(depositor, address(this), assets);

        // Approve the vault to spend the assets
        IERC20(token).forceApprove(vaultToken, assets);

        // Deposit the assets into the vault and get shares
        uint256 shares = IERC4626(vaultToken).deposit(assets, receiver);

        emit Deposit(receiver, token, assets, shares);
    }

    function _withdraw(address token, uint256 assets, address receiver, address user) internal {
        _checkTokenSupported(token);
        address vaultToken = vaultTokens[token];
        uint256 shares = IERC4626(vaultToken).withdraw(assets, receiver, user);
        emit Withdraw(receiver, user, vaultToken, assets, shares);
    }

    function _checkTokenSupported(address token) internal view {
        if (!tokens[token]) {
            revert TokenNotSupported();
        }
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------

    function governor() public view override returns (address) {
        return _governor;
    }

    /// @dev check if token is supported
    /// @param token address of the token
    function isTokenSupported(address token) public view override returns (bool) {
        return tokens[token];
    }

    /// @dev get vault token  address
    function getVaultToken(address token) public view override returns (address) {
        return vaultTokens[token];
    }

    /// @dev get user shares on specific vault
    function getUserShares(address token, address user) public view override returns (uint256) {
        address vaultToken = vaultTokens[token];
        IERC4626 vault = IERC4626(vaultToken);
        return vault.balanceOf(user);
    }

    /// @dev convert assets to shares based on the vault
    function convertToShares(address token, uint256 assets) public view override returns (uint256) {
        address vaultToken = vaultTokens[token];
        IERC4626 vault = IERC4626(vaultToken);
        return vault.convertToShares(assets);
    }

    /// @dev convert shares to assets based on the vault
    function convertToAssets(address token, uint256 shares) public view override returns (uint256) {
        address vaultToken = vaultTokens[token];
        IERC4626 vault = IERC4626(vaultToken);
        return vault.convertToAssets(shares);
    }
}
