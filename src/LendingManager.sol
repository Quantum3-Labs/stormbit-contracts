// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";

import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20} from "./interfaces/token/IERC20.sol";
import {IGovernable} from "./interfaces/utils/IGovernable.sol";
import {IInitialize} from "./interfaces/utils/IInitialize.sol";
import {IHooks} from "./interfaces/hooks/IHooks.sol";
import {IAssetManager} from "./interfaces/managers/asset/IAssetManager.sol";
import {ILoanManager} from "./interfaces/managers/loan/ILoanManager.sol";
import {ILendingManager} from "./interfaces/managers/lending/ILendingManager.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager
/// @notice entrypoint for all lender and lending terms operations

/// @dev Think of terms are minimal ERC4626, this contract is using word "shares" to represent ERC4626 assets, and "weight" to represent ERC4626 shares
contract LendingManager is Initializable, IGovernable, IInitialize, ILendingManager {
    using Checkpoints for Checkpoints.Trace224;
    using SafeERC20 for IERC20;

    uint16 public constant BASIS_POINTS = 10_000;

    address private _governor;
    IAssetManager public assetManager;
    ILoanManager public loanManager;

    mapping(uint256 => ILendingManager.LendingTerm) public lendingTerms;
    mapping(address user => mapping(uint256 termId => uint32 lastDepositTime)) public lastDepositTime;
    mapping(address user => mapping(address vaultToken => uint256 unclaimWeight)) private _unclaimProfit;
    mapping(uint256 termId => ILendingManager.LendingTermMetadata) public lendingTermMetadata;

    constructor(address initialGovernor) {
        _governor = initialGovernor;
    }

    // -----------------------------------------
    // ------------- Custom Errors -------------
    // -----------------------------------------

    error BeforeDepositToTermFailed();
    error NotGovernor();
    error NotLoanManager();
    error NotTermOwner();
    error LendingTermAlreadyExists();
    error LendingTermDoesNotExist();
    error TermHasNonZeroTokenBalance();
    error TokenNotSupported();
    error NotEnoughShares();
    error TransferFailed();
    error InsufficientSharesToWithdraw();
    error InsufficientDisposableShares();
    error InsufficientFreezedShares();
    error FailedToTransferProfit();

    /**
     * @dev Lookup to future votes is not available.
     */
    error ERC5805FutureLookup(uint256 timepoint, uint48 clock);

    // -----------------------------------------
    // ------------- Modifiers -----------------
    // -----------------------------------------

    modifier onlyGovernor() {
        if (msg.sender != _governor) revert NotGovernor();
        _;
    }

    modifier onlyLoanManager() {
        if (msg.sender != address(loanManager)) revert NotLoanManager();
        _;
    }

    modifier onlyTermOwner(uint256 termId) {
        if (lendingTerms[termId].owner != msg.sender) revert NotTermOwner();
        _;
    }

    // -----------------------------------------
    // -------- PUBLIC FUNCTIONS ---------------
    // -----------------------------------------

    function initialize(address assetManagerAddr, address loanManagerAddr) public override initializer {
        assetManager = IAssetManager(assetManagerAddr);
        loanManager = ILoanManager(loanManagerAddr);
    }

    function clock() public view virtual returns (uint32) {
        return SafeCast.toUint32(Time.timestamp());
    }

    /// @dev create a lending term
    /// @param comission comission rate
    /// @param hooks customizable hooks, reference uniswap v4 hooks
    /// @return id of the lending term
    function createLendingTerm(uint256 comission, IHooks hooks) public override returns (uint256) {
        // unique id by hashing the sender and hooks address
        uint256 termId = uint256(keccak256(abi.encode(msg.sender, comission, address(hooks))));
        if (_validLendingTerm(termId)) revert LendingTermAlreadyExists();
        lendingTerms[termId].owner = msg.sender;
        lendingTerms[termId].comission = comission;
        lendingTerms[termId].hooks = hooks;

        emit LendingTermCreated(termId, msg.sender, comission, address(hooks));
        return termId;
    }

    /// @dev remove a lending term
    /// @param termId id of the lending term
    function removeLendingTerm(uint256 termId) public override onlyTermOwner(termId) {
        if (!_validLendingTerm(termId)) revert LendingTermDoesNotExist();
        // if there are delegated shares, the term cannot be removed
        if (lendingTerms[termId].nonZeroTokenBalanceCounter > 0) revert TermHasNonZeroTokenBalance();

        delete lendingTerms[termId];
        emit LendingTermRemoved(termId);
    }

    /// @dev allow depositor to delegate shares to a lending term
    /// @param termId id of the lending term
    /// @param token address of the token
    /// @param shares amount of shares to delegate
    function depositToTerm(uint256 termId, address token, uint256 shares) public override {
        if (!_beforeDepositToTerm(termId, token, shares)) revert BeforeDepositToTermFailed();
        if (!assetManager.isTokenSupported(token)) revert TokenNotSupported();
        if (!_validLendingTerm(termId)) revert LendingTermDoesNotExist();

        address vaultToken = assetManager.getVaultToken(token);

        // get user shares in the vault
        uint256 userShares = assetManager.getUserShares(token, msg.sender);
        // check if the user has enough shares
        if (userShares < shares) revert NotEnoughShares();
        // transfer shares to lending manager
        bool isSuccess = IERC4626(vaultToken).transferFrom(msg.sender, address(this), shares);
        if (!isSuccess) revert TransferFailed();

        IERC20(vaultToken).safeTransferFrom(msg.sender, address(this), shares);
        LendingTerm storage term = lendingTerms[termId];

        uint256 prevShares = term.termBalances[vaultToken].shares.latest();

        // check if the vault token term has 0 balance
        if (prevShares == 0 && shares > 0) {
            term.nonZeroTokenBalanceCounter++;
        }

        // each time deposit, if user deposited before and not withdraw
        // add the profit into the deposited shares
        if (lastDepositTime[msg.sender][termId] > 0) {
            uint256 lastDepositShares = term.userSharesCheckpoints[msg.sender][vaultToken].upperLookupRecent(
                SafeCast.toUint32(lastDepositTime[msg.sender][termId])
            );
            uint256 userProfit = _calculateUserProfit(termId, lastDepositShares, token);
            _unclaimProfit[msg.sender][vaultToken] += userProfit;
        }

        lastDepositTime[msg.sender][termId] = clock();

        // update the amount of shares delegated to the term by the user
        // get last user shares checkpoint
        uint256 lastUserShares = term.userSharesCheckpoints[msg.sender][vaultToken].latest();
        term.userSharesCheckpoints[msg.sender][vaultToken].push(clock(), SafeCast.toUint224(lastUserShares + shares));

        uint256 newShares = prevShares + shares;
        term.termBalances[vaultToken].shares.push(clock(), SafeCast.toUint224(newShares));
        term.termBalances[vaultToken].available += shares;

        emit DepositToTerm(termId, msg.sender, token, shares);
    }

    /// @param termId id of the lending term
    /// @param token address of the token
    /// @param shares amount of shares to withdraw
    function withdrawFromTerm(uint256 termId, address token, uint256 shares) public override {
        if (!_validLendingTerm(termId)) revert LendingTermDoesNotExist();

        address vaultToken = assetManager.getVaultToken(token);
        LendingTerm storage term = lendingTerms[termId];

        uint256 totalDelegatedShares = term.userSharesCheckpoints[msg.sender][vaultToken].latest();

        // check how many percentage of shares are freezed on term
        uint256 frozenShares = term.termBalances[vaultToken].shares.latest() - term.termBalances[vaultToken].available;
        uint256 frozenSharesPercentage = (frozenShares * BASIS_POINTS) / term.termBalances[vaultToken].shares.latest();

        // get the freezeAmount from disposable shares
        uint256 freezeAmount = (totalDelegatedShares * frozenSharesPercentage) / BASIS_POINTS;

        // cannot withdraw more than disposable shares - freezeAmount
        uint256 maximumWithdraw = totalDelegatedShares - freezeAmount;

        if (shares > maximumWithdraw) revert InsufficientSharesToWithdraw();

        // calculate the profit based on the last deposit shares
        uint256 userProfit = _calculateUserProfit(termId, shares, token);

        uint256 redeemShares = userProfit + shares + _unclaimProfit[msg.sender][vaultToken];

        uint256 newProfit =
            term.termBalances[vaultToken].profit.latest() - (userProfit + _unclaimProfit[msg.sender][vaultToken]);
        term.termBalances[vaultToken].profit.push(clock(), SafeCast.toUint224(newProfit));
        uint256 newShares = term.termBalances[vaultToken].shares.latest() - shares;
        term.termBalances[vaultToken].shares.push(clock(), SafeCast.toUint224(newShares));
        term.userSharesCheckpoints[msg.sender][vaultToken].push(
            clock(), SafeCast.toUint224(totalDelegatedShares - shares)
        );

        term.termBalances[vaultToken].available -= shares;
        _unclaimProfit[msg.sender][vaultToken] = 0;
        lastDepositTime[msg.sender][termId] = 0;

        // transfer shares back to user
        bool isSuccess = IERC4626(vaultToken).transfer(msg.sender, redeemShares);
        if (!isSuccess) revert TransferFailed();
        IERC20(vaultToken).safeTransfer(msg.sender, redeemShares);

        // if term shares balance is 0, decrement the counter
        if (term.termBalances[vaultToken].shares.latest() == 0) {
            term.nonZeroTokenBalanceCounter--;
        }

        emit WithdrawFromTerm(termId, msg.sender, token, shares);
    }

    /// @dev freeze the shares on term when allocated fund to loan
    function freezeTermShares(uint256 termId, uint256 shares, address token) public override onlyLoanManager {
        if (!_validLendingTerm(termId)) revert LendingTermDoesNotExist();
        address vaultToken = assetManager.getVaultToken(token);

        LendingTerm storage term = lendingTerms[termId];

        if (term.termBalances[vaultToken].available < shares) revert InsufficientDisposableShares();

        term.termBalances[vaultToken].available -= shares;

        emit FreezeShares(termId, token, shares);
    }

    /// @dev unfreeze the shares on term allocated fund to loan
    function unfreezeTermShares(uint256 termId, uint256 shares, address token) public override onlyLoanManager {
        if (!_validLendingTerm(termId)) revert LendingTermDoesNotExist();
        _unfreezeTermShares(token, termId, shares);
    }

    function distributeProfit(uint256 termId, address token, uint256 profit, uint256 shares, uint256 ownerProfit)
        public
        override
        onlyLoanManager
    {
        if (!_validLendingTerm(termId)) revert LendingTermDoesNotExist();
  
        address vaultToken = assetManager.getVaultToken(token);
        LendingTerm storage term = lendingTerms[termId];

        // transfer profit shares to term owner
        bool isSuccess = IERC4626(vaultToken).transfer(term.owner, ownerProfit);
        if (!isSuccess) revert FailedToTransferProfit();
        IERC20(vaultToken).safeTransfer(term.owner, ownerProfit);

        uint256 newProfit = term.termBalances[vaultToken].profit.latest() + profit;

        // add profit to term checkpoint
        // get the last allocate clock time from loan
        term.termBalances[vaultToken].profit.push(
            // clock(),
            SafeCast.toUint32(executionTimestamp),
            SafeCast.toUint224(newProfit)
        );
        _unfreezeTermShares(token, termId, shares);

        emit DistributeProfit(termId, token, profit);
    }

    // -----------------------------------------
    // ---------- PRIVATE FUNCTIONS ------------
    // -----------------------------------------

    function _beforeDepositToTerm(uint256 termId, address token, uint256 shares) private returns (bool) {
        IHooks hooks = lendingTerms[termId].hooks;
        if (address(hooks) == address(0)) {
            return true;
        }
        return hooks.beforeDepositToTerm(msg.sender, token, termId, shares);
    }

    function _unfreezeTermShares(address token, uint256 termId, uint256 shares) private {
        address vaultToken = assetManager.getVaultToken(token);

        LendingTerm storage term = lendingTerms[termId];

        uint256 frozenShares = term.termBalances[vaultToken].shares.latest() - term.termBalances[vaultToken].available;

        if (shares > frozenShares) revert InsufficientFreezedShares();
        term.termBalances[vaultToken].available += shares;

        emit UnfreezeShares(termId, token, shares);
    }

    function _calculateUserProfit(uint256 termId, uint256 shares, address token) private view returns (uint256) {
        LendingTerm storage term = lendingTerms[termId];
        address vaultToken = assetManager.getVaultToken(token);

        uint256 currentTimeShares = term.termBalances[vaultToken].shares.latest();
        uint256 lastTimeProfit = term.termBalances[vaultToken].profit.upperLookupRecent(
            SafeCast.toUint32(lastDepositTime[msg.sender][termId])
        );
        uint256 currentProfit = term.termBalances[vaultToken].profit.latest();
        uint256 profit = (currentProfit - lastTimeProfit);
        // calculate the profit based on the last deposit shares
        uint256 userProfit = (shares * profit) / currentTimeShares;
        return userProfit;
    }

    // -----------------------------------------
    // ---------- INTERNAL FUNCTIONS -----------
    // -----------------------------------------

    /// @dev check if lending term exists
    /// @param termId id of the lending term
    function _validLendingTerm(uint256 termId) internal view returns (bool) {
        return lendingTerms[termId].owner != address(0);
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------

    function governor() public view override returns (address) {
        return _governor;
    }

    function getLendingTerm(uint256 termId) public view override returns (LendingTermMetadata memory) {
        LendingTerm storage term = lendingTerms[termId];
        return LendingTermMetadata(term.owner, term.comission, term.hooks);
    }

    function getLendingTermBalances(uint256 termId, address token)
        public
        view
        override
        returns (uint256, uint256, uint256)
    {
        address vaultToken = assetManager.getVaultToken(token);
        return (
            lendingTerms[termId].termBalances[vaultToken].profit.latest(),
            lendingTerms[termId].termBalances[vaultToken].available,
            lendingTerms[termId].termBalances[vaultToken].shares.latest()
        );
    }

    function getTermFreezedShares(uint256 termId, address token) public view override returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return lendingTerms[termId].termBalances[vaultToken].shares.latest()
            - lendingTerms[termId].termBalances[vaultToken].available;
    }

    /**
     * @dev Returns the `account` current delegated amount of shares on term
     */
    function getShares(address account, address token, uint256 termId) public view virtual returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return lendingTerms[termId].userSharesCheckpoints[account][vaultToken].latest();
    }

    /**
     * @dev Returns the amount of shares that `account` had delegated at a specific moment in the past. If the `clock()` is
     * configured to use block numbers, this will return the value at the end of the corresponding block.
     *
     * Requirements:
     *
     * - `timepoint` must be in the past. If operating using block numbers, the block must be already mined.
     */
    function getPastShares(address account, address token, uint256 termId, uint256 timepoint)
        public
        view
        virtual
        returns (uint256)
    {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        address vaultToken = assetManager.getVaultToken(token);
        return lendingTerms[termId].userSharesCheckpoints[account][vaultToken].upperLookupRecent(
            SafeCast.toUint32(timepoint)
        );
    }
}
