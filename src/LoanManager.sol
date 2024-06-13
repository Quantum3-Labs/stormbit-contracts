pragma solidity ^0.8.21;

import {IGovernable} from "./interfaces/IGovernable.sol";
import {ILoanRequest} from "./interfaces/ILoanRequest.sol";
import {ILendingTerms} from "./interfaces/ILendingTerms.sol";
import {IAllocation} from "./interfaces/IAllocation.sol";
import {StormbitAssetManager} from "./AssetManager.sol";
import {StormbitLendingManager} from "./LendingManager.sol";

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager
/// @notice entrypoint for loan related operations

contract StormbitLoanManager is ILoanRequest, IAllocation {
    address public governor;
    StormbitLendingManager public lendingManager;
    StormbitAssetManager public assetManager;
    uint256 public loanCounter;

    mapping(uint256 loanId => Loan loan) public loans;
    mapping(uint256 loanId => ILendingTerms.LendingTerm[] terms)
        public loanTerms;
    mapping(uint256 loanId => mapping(uint256 termId => bool isAllocated))
        public loanTermAllocated;

    constructor(address _governor) {
        governor = _governor;
    }

    // -----------------------------------------
    // ------------- Modifiers -----------------
    // -----------------------------------------

    modifier onlyGovernor() {
        require(msg.sender == governor, "StormbitAssetManager: not governor");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(
            loans[loanId].borrower == msg.sender,
            "StormbitLoanManager: not borrower"
        );
        _;
    }

    modifier onlyLender() {
        require(
            lendingManager.isRegistered(msg.sender),
            "StormbitLoanManager: not lender"
        );
        _;
    }

    // -----------------------------------------
    // -------- PUBLIC FUNCTIONS ---------------
    // -----------------------------------------

    // todo: use oz initializer
    function initialize(
        address assetManagerAddr,
        address lendingManagerAddr
    ) public {
        assetManager = StormbitAssetManager(assetManagerAddr);
        lendingManager = StormbitLendingManager(lendingManagerAddr);
    }

    /// @dev allow borrower to request loan
    /// @param token address of the token
    /// @param amount amount of token to borrow
    /// @param deadline deadline of the loan
    /// @return loanId id of the loan
    function requestLoan(
        address token,
        uint256 amount,
        uint256 deadline
    ) external override returns (uint256) {
        // check if token is supported
        require(
            assetManager.isTokenSupported(token),
            "StormbitLoanManager: token not supported"
        );
        loanCounter += 1;
        uint256 loanId = uint256(
            keccak256(abi.encode(msg.sender, loanCounter))
        );

        loans[loanId] = Loan({
            borrower: msg.sender,
            token: token,
            amount: amount,
            currentAllocated: 0,
            deadline: deadline,
            status: LoanStatus.Pending
        });

        emit LoanRequested(loanId, msg.sender, token, amount, deadline);
        return loanId;
    }

    /// @dev allow borrower to execute the loan and receive the fund
    /// @param loanId id of the loan
    function executeLoan(uint256 loanId) public onlyBorrower(loanId) {
        Loan memory loan = loans[loanId];
        require(
            loan.status == LoanStatus.Pending,
            "StormbitLoanManager: loan not pending"
        );
        require(
            loan.currentAllocated >= loan.amount,
            "StormbitLoanManager: insufficient allocation"
        );
        // withdraw by asset manager
        assetManager.withdraw(loan.token, loan.amount);
        loans[loanId].status = LoanStatus.Active;
    }

    /// @dev allow anyone to repay the loan, not restricted to borrower
    /// @param loanId id of the loan
    function repay(uint256 loanId) external override {}

    /// @dev enable the lender to allocate certain term for the loan, until the loan is fully allocated
    /// @param loanId id of the loan
    /// @param termId id of the term
    function allocateTerm(uint256 loanId, uint256 termId) public onlyLender {
        // check is valid loan
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");

        // check if term is valid
        ILendingTerms.LendingTerm memory lendingTerm = lendingManager
            .getLendingTerm(termId);
        require(
            lendingTerm.owner == msg.sender,
            "StormbitLoanManager: not term owner"
        );

        // check if term is already allocated
        require(
            !loanTermAllocated[loanId][termId],
            "StormbitLoanManager: term already allocated"
        );

        loanTermAllocated[loanId][termId] = true;
        loanTerms[loanId].push(lendingTerm);

        emit TermAllocated(loanId, termId);
    }

    function allocateFundOnLoan(
        uint256 loanId,
        uint256 termId,
        uint256 amount
    ) public onlyLender {
        // check is valid loan
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");
        // dont need to check term is valid, because it is already checked in allocateTerm
        require(
            loanTermAllocated[loanId][termId],
            "StormbitLoanManager: term not allocated"
        );
        // only owner of term can allocate fund
        ILendingTerms.LendingTerm memory lendingTerm = lendingManager
            .getLendingTerm(termId);
        require(
            lendingTerm.owner == msg.sender,
            "StormbitLoanManager: not term owner"
        );

        Loan memory loan = loans[loanId];
        // get disposable shares on token of the term
        address token = loan.token;
        // get the corresponding vault token
        address vaultToken = assetManager.getTokenVault(token);
        // get term owner disposable shares
        uint256 termOwnerDisposableShares = lendingManager
            .getDisposableSharesOnTerm(termId, vaultToken);
        require(
            termOwnerDisposableShares >= amount,
            "StormbitLoanManager: term owner insufficient disposable shares"
        );
        // fund amount should less than loan amount
        require(
            loan.currentAllocated + amount <= loan.amount,
            "StormbitLoanManager: loan amount exceeded"
        );

        // now we have term owner total disposable shares enough
        // use depositor shares to fund this loan
        // get the list of depositor
        address[] memory termDepositors = lendingManager.getTermDepositors(
            termId,
            vaultToken
        );
        for (uint256 i = 0; i < termDepositors.length; i++) {
            uint256 depositorDelegatedSharesAmount = lendingManager
                .getUserDisposableSharesOnTerm(
                    termId,
                    vaultToken,
                    termDepositors[i]
                );
            uint256 propotionToFund = (depositorDelegatedSharesAmount *
                amount) / termOwnerDisposableShares;
            // freeze the user shares
            lendingManager.freezeSharesOnTerm(
                termId,
                vaultToken,
                termDepositors[i],
                propotionToFund
            );
            // update loan current allocated
            loan.currentAllocated += propotionToFund;
        }
        // update loan at storage level
        loans[loanId] = loan;
        // todo: emit event
    }

    // -----------------------------------------
    // ----------- PRIVATEFUNCTIONS ------------
    // -----------------------------------------
    function _validLoan(uint256 loanId) private view returns (bool) {
        return loans[loanId].borrower != address(0);
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------
}
