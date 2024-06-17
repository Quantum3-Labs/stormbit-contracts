pragma solidity ^0.8.21;

import {ILendingTerms} from "./interfaces/managers/lending/ILendingTerms.sol";
import {IDelegation} from "./interfaces/managers/lending/IDelegation.sol";
import {ILenderRegistry} from "./interfaces/managers/lending/ILenderRegistry.sol";
import {ILendingManagerView} from "./interfaces/managers/lending/ILendingManagerView.sol";
import {ILendingWithdrawal} from "./interfaces/managers/lending/ILendingWithdrawal.sol";
import {ILoanRequest} from "./interfaces/managers/loan/ILoanRequest.sol";
import {IERC4626} from "./interfaces/token/IERC4626.sol";
import {IGovernable} from "./interfaces/utils/IGovernable.sol";
import {IInitialize} from "./interfaces/utils/IInitialize.sol";
import {StormbitAssetManager} from "./AssetManager.sol";
import {StormbitLoanManager} from "./LoanManager.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager
/// @notice entrypoint for all lender and lending terms operations

// todo: use custom error
contract StormbitLendingManager is
    IGovernable,
    IInitialize,
    ILendingManagerView,
    ILendingTerms,
    IDelegation,
    ILenderRegistry,
    ILendingWithdrawal,
    Initializable
{
    address private _governor;
    StormbitAssetManager public assetManager;
    StormbitLoanManager public loanManager;

    mapping(address => bool) public registeredLenders;
    mapping(uint256 => LendingTerm) public lendingTerms;
    mapping(uint256 termId => mapping(address vaultToken => Shares shares))
        public termOwnerShares; // total shares controlled by the term owner
    mapping(uint256 termId => mapping(address user => mapping(address vaultToken => uint256 shares)))
        public termUserDelegatedShares; // total shares delegated by the depositor on term
    mapping(address user => mapping(address vaultToken => uint256 delegatedShares)) // track user total delegated shares
        public userTotalDelegatedShares;
    mapping(uint256 termId => mapping(address vaultToken => uint256 shares)) termFreezedShares; // track who delegated to the term

    constructor(address initialGovernor) {
        _governor = initialGovernor;
    }

    // -----------------------------------------
    // ------------- Modifiers -----------------
    // -----------------------------------------

    modifier onlyGovernor() {
        require(msg.sender == _governor, "StormbitAssetManager: not governor");
        _;
    }

    modifier onlyRegisteredLender() {
        require(
            registeredLenders[msg.sender],
            "StormbitLendingManager: not registered lender"
        );
        _;
    }

    modifier onlyLoanManager() {
        require(
            msg.sender == address(loanManager),
            "StormbitLendingManager: not loan manager"
        );
        _;
    }

    // -----------------------------------------
    // -------- PUBLIC FUNCTIONS ---------------
    // -----------------------------------------

    function initialize(
        address assetManagerAddr,
        address loanManagerAddr
    ) public override initializer {
        assetManager = StormbitAssetManager(assetManagerAddr);
        loanManager = StormbitLoanManager(loanManagerAddr);
    }

    /// @dev register msg sender as a lender
    function register() public override {
        registeredLenders[msg.sender] = true;
        emit LenderRegistered(msg.sender);
    }

    /// @dev create a lending term
    /// @param comission comission rate
    /// @return id of the lending term
    function createLendingTerm(
        uint256 comission
    ) public override onlyRegisteredLender returns (uint256) {
        uint256 id = uint256(keccak256(abi.encode(msg.sender, comission)));
        require(
            !_validLendingTerm(id),
            "StormbitLendingManager: lending term already exists"
        );
        lendingTerms[id] = LendingTerm(msg.sender, comission, 0);
        emit LendingTermCreated(id, msg.sender, comission);
        return id;
    }

    /// @dev remove a lending term
    /// @param id id of the lending term
    function removeLendingTerm(
        uint256 id
    ) public override onlyRegisteredLender {
        require(
            _validLendingTerm(id),
            "StormbitLendingManager: lending term does not exist"
        );
        // if there are delegated shares, the term cannot be removed
        // get term
        LendingTerm memory term = lendingTerms[id];
        require(
            term.balances <= 0,
            "StormbitLendingManager: term has delegated shares"
        );

        delete lendingTerms[id];
        emit LendingTermRemoved(id);
    }

    /// @dev allow depositor to delegate shares to a lending term
    /// @param termId id of the lending term
    /// @param token address of the token
    /// @param shares amount of shares to delegate
    function depositToTerm(
        uint256 termId,
        address token,
        uint256 shares
    ) public override {
        require(
            _beforeDeposit(),
            "StormbitLendingManager: before deposit failed"
        );
        require(
            assetManager.isTokenSupported(token),
            "StormbitLendingManager: token not supported"
        );
        require(
            _validLendingTerm(termId),
            "StormbitLendingManager: lending term does not exist"
        );
        require(
            loanManager.getTermLoanAllocatedCounter(termId) == 0,
            "StormbitLendingManager: term already allocated to loan"
        );

        address vaultToken = assetManager.getVaultToken(token);
        // get current delegated shares to the term
        uint256 currentDelegatedShares = userTotalDelegatedShares[msg.sender][
            vaultToken
        ];
        uint256 userCurrentTotalDelegatedShares = currentDelegatedShares +
            shares;
        // get user shares in the vault
        uint256 userShares = assetManager.getUserShares(token, msg.sender);
        // check if the user has enough shares
        require(
            userShares >= userCurrentTotalDelegatedShares,
            "StormbitLendingManager: not enough shares"
        );

        // transfer shares to lending manager
        bool isSuccess = IERC4626(vaultToken).transferFrom(
            msg.sender,
            address(this),
            shares
        );
        if (!isSuccess) {
            revert("StormbitLendingManager: failed to transfer shares");
        }

        // update the amount of shares delegated to the term by the user
        termUserDelegatedShares[termId][msg.sender][vaultToken] += shares;
        // update user total delegated shares, prevent scenario delegate more than user has
        userTotalDelegatedShares[msg.sender][
            vaultToken
        ] = userCurrentTotalDelegatedShares;

        // update term total disposable shares (allowance)
        termOwnerShares[termId][vaultToken].disposableAmount += shares;
        termOwnerShares[termId][vaultToken].totalAmount += shares;

        // update term balance
        lendingTerms[termId].balances += shares;

        emit DepositToTerm(termId, msg.sender, vaultToken, shares);
    }

    /// @dev allow lender to decrease delegated shares to a lending term
    /// @param termId id of the lending term
    /// @param token address of the token
    /// @param shares amount of shares to decrease
    function withdrawFromTerm(
        uint256 termId,
        address token,
        uint256 shares
    ) public override {
        require(
            _validLendingTerm(termId),
            "StormbitLendingManager: lending term does not exist"
        );
        address vaultToken = assetManager.getVaultToken(token);
        // currenly "disposable" shares
        uint256 totalDelegatedShares = termUserDelegatedShares[termId][
            msg.sender
        ][vaultToken];

        // check how many percentage of shares are freezed on term
        uint256 freezedShares = termFreezedShares[termId][vaultToken];
        uint256 freezedSharesPercentage = (freezedShares * 100) /
            termOwnerShares[termId][vaultToken].totalAmount;
        // get the freezeAmount from disposable shares
        uint256 freezeAmount = (totalDelegatedShares *
            freezedSharesPercentage) / 100;

        // cannot withdraw more than disposable shares - freezeAmount
        uint256 maximumWithdraw = totalDelegatedShares - freezeAmount;

        // check if the user has enough unfreezed shares
        require(
            shares <= maximumWithdraw,
            "StormbitLendingManager: insufficient shares to withdraw"
        );

        termUserDelegatedShares[termId][msg.sender][vaultToken] -= shares;
        userTotalDelegatedShares[msg.sender][vaultToken] -= shares;

        // calculate weight of user in shares / term total shares
        uint256 weight = (shares * 100) /
            termOwnerShares[termId][vaultToken].totalAmount;
        // give user the profit
        uint256 profit = (termOwnerShares[termId][vaultToken].profit * weight) /
            100;

        termOwnerShares[termId][vaultToken].totalAmount -= shares;
        termOwnerShares[termId][vaultToken].disposableAmount -= shares;
        termOwnerShares[termId][vaultToken].profit -= profit;

        // update term balance
        lendingTerms[termId].balances -= shares;

        // transfer shares back to user
        bool isSuccess = IERC4626(vaultToken).transfer(
            msg.sender,
            shares + profit
        );
        if (!isSuccess) {
            revert("StormbitLendingManager: failed to transfer shares");
        }

        emit WithdrawFromTerm(termId, msg.sender, vaultToken, shares);
    }

    function claimLoanProfit(
        uint256 termId,
        uint256 loanId,
        address token
    ) public override {
        // todo: add another mapping to prevent double claim
        // get term owner
        address termOwner = lendingTerms[termId].owner;
        require(
            msg.sender == termOwner,
            "StormbitLendingManager: not term owner"
        );
        // get loan
        ILoanRequest.Loan memory loan = loanManager.getLoan(loanId);
        require(
            loan.status == ILoanRequest.LoanStatus.Repaid,
            "StormbitLendingManager: loan not repaid"
        );
        address vaultToken = assetManager.getVaultToken(token);
        // now check the weight of term in loan
        uint256 weight = loanManager.getTermAllocatedSharesOnLoan(
            loanId,
            termId,
            vaultToken
        );
        ILendingTerms.LendingTerm memory term = lendingTerms[termId];
        uint256 termFundedPercent = (weight * 100) / loan.sharesRequired;
        uint256 fund = (loan.repayAmount * termFundedPercent) / 100;
        uint256 commission = (fund * term.comission) / 10000;

        // transfer commission shares to term owner
        bool isSuccess = IERC4626(vaultToken).transfer(termOwner, commission);
        if (!isSuccess) {
            revert("StormbitLendingManager: failed to transfer commission");
        }

        // the rest add to term balance
        uint256 profit = fund - commission;
        termOwnerShares[termId][vaultToken].disposableAmount += profit;
        // calculate profit - expenses and all to total amount
        uint256 extra = profit - weight;
        termOwnerShares[termId][vaultToken].profit += extra;
    }

    function freezeTermShares(
        uint256 termId,
        uint256 shares,
        address token
    ) public override onlyLoanManager {
        require(
            _validLendingTerm(termId),
            "StormbitLendingManager: lending term does not exist"
        );
        address vaultToken = assetManager.getVaultToken(token);
        require(
            termOwnerShares[termId][vaultToken].disposableAmount >= shares,
            "StormbitLendingManager: insufficient disposable shares"
        );
        termFreezedShares[termId][vaultToken] += shares;
        termOwnerShares[termId][vaultToken].disposableAmount -= shares;
        lendingTerms[termId].balances -= shares;
    }

    function borrowerWithdraw(
        address borrower,
        address token,
        uint256 shares
    ) public override onlyLoanManager {
        address vaultToken = assetManager.getVaultToken(token);
        IERC4626(vaultToken).approve(address(assetManager), shares);
        assetManager.borrowerWithdraw(borrower, vaultToken, shares);
    }

    // -----------------------------------------
    // ---------- PRIVATE FUNCTIONS ------------
    // -----------------------------------------
    function _beforeDeposit() private returns (bool) {
        return true;
    }

    // -----------------------------------------
    // ---------- INTERNAL FUNCTIONS -----------
    // -----------------------------------------

    /// @dev check if lending term exists
    /// @param id id of the lending term
    function _validLendingTerm(uint256 id) internal view returns (bool) {
        return lendingTerms[id].owner != address(0);
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------

    function governor() public view override returns (address) {
        return _governor;
    }

    /// @dev check a lenders is registered
    /// @param lender address of the lender
    function isRegistered(address lender) public view override returns (bool) {
        return registeredLenders[lender];
    }

    function getLendingTerm(
        uint256 id
    ) public view override returns (LendingTerm memory) {
        return lendingTerms[id];
    }

    /// @dev get the owner's vault token disposable shares on a term
    function getDisposableSharesOnTerm(
        uint256 termId,
        address token
    ) public view override returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return termOwnerShares[termId][vaultToken].disposableAmount;
    }

    function getUserTotalDelegatedShares(
        address user,
        address token
    ) public view override returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return userTotalDelegatedShares[user][vaultToken];
    }
}
