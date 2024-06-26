pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IGovernable} from "./interfaces/utils/IGovernable.sol";
import {IInitialize} from "./interfaces/utils/IInitialize.sol";
import {IERC4626} from "./interfaces/token/IERC4626.sol";
import {IAssetManager} from "./interfaces/managers/asset/IAssetManager.sol";
import {ILoanManager} from "./interfaces/managers/loan/ILoanManager.sol";
import {ILendingManager} from "./interfaces/managers/lending/ILendingManager.sol";

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager
/// @notice entrypoint for loan related operations

contract StormbitLoanManager is
    Initializable,
    IGovernable,
    IInitialize,
    ILoanManager
{
    address private _governor;
    uint256 public loanCounter;

    ILendingManager public lendingManager;
    IAssetManager public assetManager;

    mapping(uint256 loanId => Loan loan) public loans;
    mapping(uint256 loanId => mapping(uint256 termId => mapping(address vaultToken => uint256 shares)))
        public termAllocatedShares;
    mapping(uint256 loanId => mapping(uint256 termId => bool isAllocated))
        public loanTermAllocated;
    // a counter use to track amount of loans a term was allocated to
    mapping(uint256 termId => uint256 loanAllocated) termLoanAllocatedCounter;

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

    modifier onlyBorrower(uint256 loanId) {
        require(
            loans[loanId].borrower == msg.sender,
            "StormbitLoanManager: not borrower"
        );
        _;
    }

    // -----------------------------------------
    // -------- PUBLIC FUNCTIONS ---------------
    // -----------------------------------------

    function initialize(
        address assetManagerAddr,
        address lendingManagerAddr
    ) public override initializer {
        assetManager = IAssetManager(assetManagerAddr);
        lendingManager = ILendingManager(lendingManagerAddr);
    }

    /// @dev allow borrower to request loan
    /// @param token address of the token
    /// @param assets amount of token to borrow
    /// @param deadline deadline of the loan to be allocated
    /// @return loanId id of the loan
    function requestLoan(
        address token,
        uint256 assets,
        uint256 deadline
    ) public override returns (uint256) {
        // todo: see which agreement to use

        // check if token is supported
        require(
            assetManager.isTokenSupported(token),
            "StormbitLoanManager: token not supported"
        );
        loanCounter += 1;
        uint256 loanId = uint256(
            keccak256(abi.encode(msg.sender, loanCounter))
        );

        // calculate shares required to fulfill the loan
        // todo: do safety check if amount is zero
        // todo: should be fine to remove, convertToShares has totalAssets() + 1, will not lead to 0
        uint256 sharesRequired = _calculateSharesRequired(token, assets);
        require(sharesRequired > 0, "StormbitLoanManager: insufficient shares");

        // todo: change the fixed rate
        // 5% interest rate
        uint256 repayAssets = assets + (assets * 5) / 100;

        loans[loanId] = Loan({
            borrower: msg.sender,
            token: token,
            repayAssets: repayAssets,
            sharesRequired: sharesRequired,
            sharesAllocated: 0,
            deadlineAllocate: deadline,
            status: LoanStatus.Pending
        });

        emit LoanRequested(loanId, msg.sender, token, assets);
        return loanId;
    }

    /// @dev allow borrower to execute the loan and receive the fund
    /// @param loanId id of the loan
    function executeLoan(uint256 loanId) public override onlyBorrower(loanId) {
        Loan memory loan = loans[loanId];
        // require valid loan
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");
        require(
            loan.status == LoanStatus.Pending,
            "StormbitLoanManager: loan not pending"
        );
        require(
            loan.sharesAllocated >= loan.sharesRequired,
            "StormbitLoanManager: insufficient allocation"
        );
        // only if deadline is passed
        require(
            block.timestamp >= loan.deadlineAllocate,
            "StormbitLoanManager: deadline not passed"
        );
        loans[loanId].status = LoanStatus.Active;
        lendingManager.borrowerWithdraw(
            // withdraw by asset manager
            loan.borrower,
            loan.token,
            loan.sharesRequired
        );
        emit LoanExecuted(loanId, loan.borrower, loan.token, loan.repayAssets);
    }

    /// @dev allow anyone to repay the loan, not restricted to borrower
    /// @param loanId id of the loan
    function repay(uint256 loanId) public override {
        // check if loan is valid
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");
        Loan memory loan = loans[loanId];
        require(
            loan.status == LoanStatus.Active,
            "StormbitLoanManager: loan not active"
        );
        assetManager.depositFrom(
            loan.token,
            loan.repayAssets,
            msg.sender,
            address(lendingManager)
        );
        loans[loanId].status = LoanStatus.Repaid;
        emit LoanRepaid(loanId, msg.sender);
    }

    /// @dev enable the lender to allocate certain term for the loan, until the loan is fully allocated
    /// @param loanId id of the loan
    /// @param termId id of the term
    function allocateTerm(uint256 loanId, uint256 termId) public override {
        // check is valid loan
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");
        // only if allocate deadline not passed
        require(
            block.timestamp < loans[loanId].deadlineAllocate,
            "StormbitLoanManager: deadline passed"
        );

        // check if term is valid
        ILendingManager.LendingTerm memory lendingTerm = lendingManager
            .getLendingTerm(termId);
        require(
            lendingTerm.owner == msg.sender,
            "StormbitLoanManager: not term owner"
        );
        // get loan instance
        Loan memory loan = loans[loanId];
        // check if term capable to fund the loan
        require(
            lendingManager.getDisposableSharesOnTerm(termId, loan.token) > 0,
            "StormbitLoanManager: term insufficient shares"
        );

        // check if term is already allocated
        require(
            !loanTermAllocated[loanId][termId],
            "StormbitLoanManager: term already allocated"
        );

        loanTermAllocated[loanId][termId] = true;
        termLoanAllocatedCounter[termId] += 1; // ! todo: !where to decrement this?

        emit TermAllocated(loanId, termId);
    }

    /// @dev allow lender to allocate fund on the loan, but only when the term is already allocated
    /// @param loanId id of the loan
    /// @param termId id of the term
    /// @param assets amount of token to allocate
    function allocateFundOnLoan(
        uint256 loanId,
        uint256 termId,
        uint256 assets
    ) public override {
        // check is valid loan
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");
        // dont need to check term is valid, because it is already checked in allocateTerm
        require(
            loanTermAllocated[loanId][termId],
            "StormbitLoanManager: term not allocated"
        );
        // only if allocate deadline not passed
        require(
            block.timestamp < loans[loanId].deadlineAllocate,
            "StormbitLoanManager: deadline passed"
        );
        // only owner of term can allocate fund
        ILendingManager.LendingTerm memory lendingTerm = lendingManager
            .getLendingTerm(termId);
        require(
            lendingTerm.owner == msg.sender,
            "StormbitLoanManager: not term owner"
        );

        Loan memory loan = loans[loanId];
        // get disposable shares on token of the term
        address token = loan.token;
        // get the corresponding vault token
        address vaultToken = assetManager.getVaultToken(token);
        // get term owner disposable shares
        uint256 termOwnerDisposableShares = lendingManager
            .getDisposableSharesOnTerm(termId, token);
        // convert assets to shares
        uint256 sharesRequired = assetManager.convertToShares(token, assets);
        require(
            termOwnerDisposableShares >= sharesRequired,
            "StormbitLoanManager: term owner insufficient disposable shares"
        );
        // fund shares should less than loan shares required
        require(
            loan.sharesAllocated + sharesRequired <= loan.sharesRequired,
            "StormbitLoanManager: loan shares required exceeded"
        );

        // freeze the term owner shares
        lendingManager.freezeTermShares(termId, sharesRequired, token);

        loans[loanId].sharesAllocated += sharesRequired;
        termAllocatedShares[loanId][termId][vaultToken] += sharesRequired;
        emit AllocatedFundOnLoan(loanId, termId, assets);
    }

    // -----------------------------------------
    // ----------- PRIVATE FUNCTIONS -----------
    // -----------------------------------------
    function _validLoan(uint256 loanId) private view returns (bool) {
        return loans[loanId].borrower != address(0);
    }

    function _calculateSharesRequired(
        address token,
        uint256 assets
    ) private view returns (uint256) {
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
    function getLoan(
        uint256 loanId
    ) public view override returns (Loan memory) {
        return loans[loanId];
    }

    /// @dev get the allocation status of a term on a loan
    function getLoanTermAllocated(
        uint256 loanId,
        uint256 termId
    ) public view override returns (bool) {
        return loanTermAllocated[loanId][termId];
    }

    /// @dev get the amount of loans a term was allocated to
    function getTermLoanAllocatedCounter(
        uint256 termId
    ) external view override returns (uint256) {
        return termLoanAllocatedCounter[termId];
    }

    /// @dev get the allocated shares on the loan
    function getTermAllocatedSharesOnLoan(
        uint256 loanId,
        uint256 termId,
        address token
    ) public view override returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return termAllocatedShares[loanId][termId][vaultToken];
    }
}
