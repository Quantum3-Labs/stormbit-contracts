pragma solidity ^0.8.21;

import {IDepositWithdraw} from "./interfaces/IDepositWithdraw.sol";
import {IGovernable} from "./interfaces/IGovernable.sol";
import {IAssetManager} from "./interfaces/IAssetManager.sol";
import {BaseVault} from "./vaults/BaseVault.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {StormbitLoanManager} from "./LoanManager.sol";
import {StormbitLendingManager} from "./LendingManager.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @author Quantum3 Labs
/// @title Stormbit Asset Manager
/// @notice entrypoint for all asset management operations

contract StormbitAssetManager is IDepositWithdraw, IGovernable, IAssetManager {
    using Math for uint256;
    address private _governor;
    StormbitLoanManager loanManager;
    StormbitLendingManager lendingManager;

    mapping(address token => bool isSupported) tokens; // check if token is supported
    mapping(address token => address tokenVault) tokenVaults; // token to vault mapping

    uint256 public constant SHARE_DECIMAL_OFFSET = 8;

    constructor(address initialGovernor) {
        _governor = initialGovernor;
    }

    modifier onlyGovernor() {
        require(msg.sender == _governor, "StormbitAssetManager: not governor");
        _;
    }

    modifier onlyLoanManager() {
        require(
            msg.sender == address(loanManager),
            "StormbitAssetManager: not loan manager"
        );
        _;
    }

    // -----------------------------------------
    // -------- PUBLIC FUNCTIONS ---------------
    // -----------------------------------------

    // todo: use oz initializer
    function initialize(
        address loanManagerAddr,
        address lendingManagerAddr
    ) public {
        loanManager = StormbitLoanManager(loanManagerAddr);
        lendingManager = StormbitLendingManager(lendingManagerAddr);
    }

    /// @dev allow depositor deposit assets to the vault
    /// @param token address of the token
    /// @param assets amount of assets to deposit
    function deposit(address token, uint256 assets) public override {
        require(tokens[token], "StormbitAssetManager: token not supported");
        address tokenVault = tokenVaults[token]; // get the corresponding vault
        // first make sure can transfer user token to manager
        // todo: use safe transfer
        bool isSuccess = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            assets
        );
        if (!isSuccess) {
            revert("StormbitAssetManager: transfer failed");
        }
        IERC20(token).approve(tokenVault, assets);
        IERC4626(tokenVault).deposit(assets, msg.sender);
        // todo: either approve the vault to spend vault token here
        // todo: or perform a 2 step when execute loan
        emit Deposit(msg.sender, token, assets);
    }

    function depositFrom(
        address token,
        uint256 assets,
        address depositor,
        address receiver
    ) public {
        require(tokens[token], "StormbitAssetManager: token not supported");
        address tokenVault = tokenVaults[token]; // get the corresponding vault
        // first make sure can transfer user token to manager
        bool isSuccess = IERC20(token).transferFrom(
            depositor,
            address(this),
            assets
        );
        if (!isSuccess) {
            revert("StormbitAssetManager: transfer failed");
        }
        IERC20(token).approve(tokenVault, assets);
        IERC4626(tokenVault).deposit(assets, receiver);
        emit Deposit(receiver, token, assets);
    }

    /// @dev note that we dont require the token to be whitelisted
    function withdraw(address token, uint256 shares) public override {
        // if freezed, prevent withdraw
        // emit Withdraw(msg.sender, token, assets);
    }

    /// @dev allow borrower to withdraw assets from the vault
    /// @param loanId id of the loan
    /// @param borrower address of the borrower
    /// @param tokenVault address of the token vault
    /// @param loanParticipators array of borrower addresses, each borrower has different amount of shares to lend
    function borrowerWithdraw(
        uint256 loanId,
        address borrower,
        address tokenVault,
        address[] calldata loanParticipators
    ) public onlyLoanManager {
        // loop through all loanParticipators
        for (uint256 i = 0; i < loanParticipators.length; i++) {
            address participator = loanParticipators[i];
            StormbitLoanManager.LoanParticipator
                memory loanParticipator = loanManager.getLoanParticipator(
                    loanId,
                    borrower
                );
            IERC4626(tokenVault).redeem(
                loanParticipator.shares,
                borrower,
                participator
            );
        }

        // todo: emit event
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
        // todo: add event
    }

    /// @dev allow governor to remove the support of a token
    /// @param token address of the token
    function removeToken(address token) public override onlyGovernor {
        tokens[token] = false;
    }

    function approve(
        address depositor,
        address vaultToken,
        uint256 shares
    ) public onlyLoanManager {
        BaseVault(vaultToken).approve(depositor, address(this), shares);
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------

    function governor() public view override returns (address) {
        return _governor;
    }

    /// @dev check if token is supported
    /// @param token address of the token
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

    function convertToShares(
        address token,
        uint256 assets
    ) public view returns (uint256) {
        address tokenVault = tokenVaults[token];
        IERC4626 vault = IERC4626(tokenVault);
        return vault.convertToShares(assets);
    }

    function convertToAssets(
        address token,
        uint256 shares
    ) public view returns (uint256) {
        address tokenVault = tokenVaults[token];
        IERC4626 vault = IERC4626(tokenVault);
        return vault.convertToAssets(shares);
    }
}
