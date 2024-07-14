// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IGovernable} from "./interfaces/utils/IGovernable.sol";
import {IInitialize} from "./interfaces/utils/IInitialize.sol";
import {IERC4626} from "./interfaces/token/IERC4626.sol";
import {IAssetManager} from "./interfaces/managers/asset/IAssetManager.sol";
import {ILoanManager} from "./interfaces/managers/loan/ILoanManager.sol";
import {ILendingManager} from "./interfaces/managers/lending/ILendingManager.sol";

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager
/// @notice entrypoint for loan related operations

contract LoanManager is Initializable, IGovernable, IInitialize, ILoanManager {
    uint16 public constant BASIS_POINTS = 10_000;

    address private _governor;

    mapping(address user => uint256 counter) public userLoanNonce;

    ILendingManager public lendingManager;
    IAssetManager public assetManager;

    mapping(uint256 loanId => Loan loan) public loans;
    mapping(uint256 loanId => mapping(uint256 termId => mapping(address vaultToken => uint256 shares))) public
        allocatedShares;
    mapping(uint256 termId => mapping(uint256 loanId => mapping(address vaultToken => bool))) private claimedProfit; // mapping to track lender claim profit

    constructor(address initialGovernor) {
        _governor = initialGovernor;
    }

    // -----------------------------------------
    // ------------- Custom Errors -------------
    // -----------------------------------------

    error NotGovernor();
    error NotBorrower();
    error NotTermOwner();
    error TokenNotSupported();
    error InvalidLoan();
    error LoanNotPending();
    error InsufficientAllocation();
    error LoanNotActive();
    error LoanAssetsRequiredExceeded();
    error ProfitAlreadyClaimed();
    error LoanNotEligibleForClaiming();
    error FailedToTransferProfit();

    // -----------------------------------------
    // ------------- Modifiers -----------------
    // -----------------------------------------

    modifier onlyGovernor() {
        if (msg.sender != _governor) revert NotGovernor();
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        if (loans[loanId].borrower != msg.sender) revert NotBorrower();
        _;
    }

    modifier onlyTermOwner(uint256 termId) {
        address owner = lendingManager.getLendingTerm(termId).owner;
        if (owner != msg.sender) revert NotTermOwner();
        _;
    }

    // -----------------------------------------
    // -------- PUBLIC FUNCTIONS ---------------
    // -----------------------------------------

    function initialize(address assetManagerAddr, address lendingManagerAddr) public override initializer {
        assetManager = IAssetManager(assetManagerAddr);
        lendingManager = ILendingManager(lendingManagerAddr);
    }

    /// @dev allow borrower to request loan
    /// @param token address of the token
    /// @param assets amount of token to borrow
    /// @param deadline deadline of the loan to be allocated
    /// @return loanId id of the loan
    function requestLoan(address token, uint256 assets, uint256 deadline) public override returns (uint256) {
        // todo: see which agreement to use

        // check if token is supported
        if (!assetManager.isTokenSupported(token)) revert TokenNotSupported();

        uint256 loanNonce = userLoanNonce[msg.sender];
        uint256 loanId = uint256(keccak256(abi.encode(msg.sender, loanNonce)));
        loanNonce += 1;
        userLoanNonce[msg.sender] = loanNonce;

        // todo: change the fixed rate
        // 5% interest rate
        uint256 repayAssets = assets + (assets * 500) / BASIS_POINTS;

        loans[loanId] = Loan({
            borrower: msg.sender,
            token: token,
            repayAssets: repayAssets,
            assetsRequired: assets,
            assetsAllocated: 0,
            sharesAllocated: 0,
            deadlineAllocate: deadline,
            status: LoanStatus.Pending,
            executionTimestamp: 0
        });

        emit LoanRequested(loanId, msg.sender, token, assets);
        return loanId;
    }

    /// @dev allow borrower to execute the loan and receive the fund
    /// @param loanId id of the loan
    function executeLoan(uint256 loanId) public override onlyBorrower(loanId) {
        Loan memory loan = loans[loanId];
        // require valid loan
        if (!_validLoan(loanId)) revert InvalidLoan();
        if (loan.status != LoanStatus.Pending) revert LoanNotPending();
        if (loan.assetsAllocated < loan.assetsRequired) revert InsufficientAllocation();

        assetManager.withdrawTo(
            // withdraw by asset manager
            loan.borrower,
            loan.token,
            loan.assetsRequired
        );

        // only after withdraw is successful

        loans[loanId].status = LoanStatus.Active;
        loans[loanId].executionTimestamp = block.timestamp;
        emit LoanExecuted(loanId, loan.borrower, loan.token, loan.repayAssets);
    }

    /// @dev allow anyone to repay the loan, not restricted to borrower
    /// @param loanId id of the loan
    function repay(uint256 loanId) public override {
        // check if loan is valid
        if (!_validLoan(loanId)) revert InvalidLoan();
        Loan memory loan = loans[loanId];
        if (loan.status != LoanStatus.Active) revert LoanNotActive();
        assetManager.depositFrom(loan.token, loan.repayAssets, msg.sender, address(lendingManager));
        loans[loanId].status = LoanStatus.Repaid;

        emit LoanRepaid(loanId, msg.sender);
    }

    /// @dev allow lender to allocate fund on the loan, but only when the term is already allocated
    /// @param loanId id of the loan
    /// @param termId id of the term
    /// @param assets amount of token to allocate
    function allocate(uint256 loanId, uint256 termId, uint256 assets) public override onlyTermOwner(termId) {
        Loan memory loan = loans[loanId];
        // check is valid loan
        if (!_validLoan(loanId)) revert InvalidLoan();
        // only if allocate deadline not passed
        if (block.timestamp >= loan.deadlineAllocate) revert LoanNotEligibleForClaiming();

        // get disposable shares on token of the term
        address token = loan.token;
        uint256 assetsAllocated = loan.assetsAllocated;
        uint256 sharesAllocated = loan.sharesAllocated;
        // get the corresponding vault token
        address vaultToken = assetManager.getVaultToken(token);
        // get term owner disposable shares
        (, uint256 sharesAvailable,) = lendingManager.getLendingTermBalances(termId, token);
        // convert assets to shares
        uint256 sharesRequired = assetManager.convertToShares(token, assets);
        // fund shares should less than loan shares required
        sharesAllocated += sharesRequired;
        if (termOwnerDisposableShares < sharesRequired) revert InsufficientAllocation();
        // fund shares should less than loan shares required

        assetsAllocated += assets;
        if (loan.assetsAllocated + assets > loan.assetsRequired) revert LoanAssetsRequiredExceeded();

        // freeze the term owner shares
        lendingManager.freezeTermShares(termId, sharesRequired, token);

        loans[loanId].sharesAllocated = sharesAllocated;
        loans[loanId].assetsAllocated = assetsAllocated;
        allocatedShares[loanId][termId][vaultToken] += sharesRequired;

        emit Allocate(loanId, termId, assets);
    }

    /// @dev claim the profit for loan and add the remaining profit to term profit or
    /// claim the allocated fund to loan but loan deadline pass and not executed
    function claim(uint256 loanId, uint256 termId) public override {
        Loan memory loan = loans[loanId];
        address vaultToken = assetManager.getVaultToken(loan.token);

        if (loan.status != ILoanManager.LoanStatus.Repaid && loan.status != ILoanManager.LoanStatus.Pending) {
            revert LoanNotEligibleForClaiming();
        }
        // term allocated on shares should > 0
        uint256 weight = allocatedShares[loanId][termId][vaultToken];
        if (weight <= 0) revert InsufficientAllocation();

        if (loan.status == ILoanManager.LoanStatus.Repaid) {
            // check if the profit has been claimed
            if (claimedProfit[termId][loanId][vaultToken]) {
                revert ProfitAlreadyClaimed();
            }
            // get lending term
            ILendingManager.LendingTermMetadata memory term = lendingManager.getLendingTerm(termId);
            // convert repay assets to shares
            uint256 repayShares = assetManager.convertToShares(loan.token, loan.repayAssets);
            // calculate profit
            // calculate shares required, convert assets to shares
            uint256 sharesRequired = assetManager.convertToShares(loan.token, loan.assetsRequired);
            // calculate weight of term in shares / loan required shares
            uint256 termFundedPercent = (weight * BASIS_POINTS) / sharesRequired;
            uint256 profitShares = repayShares - sharesRequired;
            // term owner profit shares
            uint256 termProfitShares = (profitShares * termFundedPercent) / BASIS_POINTS;
            // from term profit shares, get commission for term owner
            uint256 termOwnerProfitShares = (termProfitShares * term.comission) / BASIS_POINTS;
            // calculate the remaining profit after term owner profit
            uint256 extraProfit = termProfitShares - termOwnerProfitShares;

            lendingManager.distributeProfit(
                termId, loan.token, extraProfit, weight, termOwnerProfitShares, loan.executionTimestamp
            );

            // update claimed status
            claimedProfit[termId][loanId][vaultToken] = true;

            emit ClaimAllocation(termId, loanId, loan.token, termOwnerProfitShares);
        } else if (loan.status == ILoanManager.LoanStatus.Pending) {
            // if block.timestamp not passed the deadline
            if (block.timestamp < loan.deadlineAllocate) {
                revert LoanNotEligibleForClaiming();
            }
            // If the loan deadline has passed and was not executed, unfreeze the term shares
            lendingManager.unfreezeTermShares(termId, weight, loan.token);
            // update loan status to cancelled
            loans[loanId].status = ILoanManager.LoanStatus.Cancelled;

            emit ClaimAllocation(termId, loanId, loan.token, weight);
        }
    }

    // -----------------------------------------
    // ----------- PRIVATE FUNCTIONS -----------
    // -----------------------------------------
    function _validLoan(uint256 loanId) private view returns (bool) {
        return loans[loanId].borrower != address(0);
    }

    function _calculateSharesRequired(address token, uint256 assets) private view returns (uint256) {
        // get the vault token
        address vaultToken = assetManager.getVaultToken(token);
        // convert assets to shares
        uint256 sharesRequired = IERC4626(vaultToken).convertToShares(assets);
        return sharesRequired;
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------
    function governor() public view override returns (address) {
        return _governor;
    }

    /// @dev get the loan details
    function getLoan(uint256 loanId) public view override returns (Loan memory) {
        return loans[loanId];
    }

    /// @dev get the allocated shares on the loan
    function getAllocatedShares(uint256 loanId, uint256 termId, address token) public view override returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return allocatedShares[loanId][termId][vaultToken];
    }
}
