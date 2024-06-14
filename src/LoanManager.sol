pragma solidity ^0.8.21;

import {IGovernable} from "./interfaces/IGovernable.sol";
import {ILoanRequest} from "./interfaces/ILoanRequest.sol";
import {ILendingTerms} from "./interfaces/ILendingTerms.sol";
import {IAllocation} from "./interfaces/IAllocation.sol";
import {IERC4626} from "./interfaces/IERC4626.sol";
import {StormbitAssetManager} from "./AssetManager.sol";
import {StormbitLendingManager} from "./LendingManager.sol";

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager
/// @notice entrypoint for loan related operations

// todo: be aware of denial of service on for loop
contract StormbitLoanManager is ILoanRequest, IAllocation {
    // todo: move to interface
    struct LoanParticipator {
        address user;
        address token;
        address vaultToken;
        uint256 shares;
        uint256 termId;
    }

    address public governor;
    StormbitLendingManager public lendingManager;
    StormbitAssetManager public assetManager;
    uint256 public loanCounter;

    mapping(uint256 loanId => Loan loan) public loans;
    mapping(uint256 loanId => ILendingTerms.LendingTerm[] terms)
        public loanTerms;
    mapping(uint256 loanId => mapping(uint256 termId => bool isAllocated))
        public loanTermAllocated;
    mapping(uint256 loanId => address[] participators)
        public participatorsAddresses;
    mapping(uint256 loanId => mapping(address depositor => LoanParticipator loanParticipator))
        public loanParticipators;

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
        uint256 sharesRequired = _calculateSharesRequired(token, amount);
        require(sharesRequired > 0, "StormbitLoanManager: insufficient amount");

        loans[loanId] = Loan({
            borrower: msg.sender,
            token: token,
            tokenVault: assetManager.getTokenVault(token),
            amount: amount,
            sharesAmount: sharesRequired,
            currentSharesAllocated: 0,
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
        // require valid loan
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");
        require(
            loan.status == LoanStatus.Pending,
            "StormbitLoanManager: loan not pending"
        );
        require(
            loan.currentSharesAllocated >= loan.sharesAmount,
            "StormbitLoanManager: insufficient allocation"
        );
        // withdraw by asset manager
        assetManager.borrowerWithdraw(
            loanId,
            loan.borrower,
            loan.tokenVault,
            participatorsAddresses[loanId]
        );
        loans[loanId].status = LoanStatus.Active;
    }

    /// @dev allow anyone to repay the loan, not restricted to borrower
    /// @param loanId id of the loan
    function repay(uint256 loanId) external override {
        // check if loan is valid
        require(_validLoan(loanId), "StormbitLoanManager: invalid loan");
        Loan memory loan = loans[loanId];
        require(
            loan.status == LoanStatus.Active,
            "StormbitLoanManager: loan not active"
        );
        // todo: if there is any profit, first pay the profit to the term owner according to their weight
        // example: profit 500: distribute the profit to three terms, 100, 200, 200
        // calculate commission for term owner, and distribute the rest to the depositor??

        // loop through the loan participators
        address[] memory participators = participatorsAddresses[loanId];
        for (uint256 i = 0; i < participators.length; i++) {
            LoanParticipator memory participator = loanParticipators[loanId][
                participators[i]
            ];
            // get the shares of the participator
            uint256 shares = participator.shares;
            // get the  token
            address token = participator.token;
            // get the amount of token to repay
            uint256 amount = assetManager.convertToAssets(token, shares);
            // transfer the token to the vault, and mint back participator shares
            assetManager.depositFrom(
                token,
                amount,
                msg.sender,
                participator.user
            );
            // unfreeze the shares
            lendingManager.unfreezeSharesOnTerm(
                participator.termId,
                participator.vaultToken,
                participators[i],
                shares
            );
        }
    }

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
        // get loan instance
        Loan memory loan = loans[loanId];
        // check if term capable to fund the loan
        require(
            lendingManager.getDisposableSharesOnTerm(termId, loan.tokenVault) >
                0,
            "StormbitLoanManager: term insufficient amount"
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
            loan.currentSharesAllocated + amount <= loan.sharesAmount,
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
                    termDepositors[i],
                    vaultToken
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
            // check if user already participate in this loan
            if (
                loanParticipators[loanId][termDepositors[i]].user == address(0)
            ) {
                loanParticipators[loanId][
                    termDepositors[i]
                ] = LoanParticipator({
                    user: termDepositors[i],
                    token: token,
                    termId: termId,
                    vaultToken: vaultToken,
                    shares: propotionToFund
                });
                participatorsAddresses[loanId].push(termDepositors[i]);
            } else {
                loanParticipators[loanId][termDepositors[i]]
                    .shares += propotionToFund;
            }
            // update loan current allocated
            loan.currentSharesAllocated += propotionToFund;
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

    function _calculateSharesRequired(
        address token,
        uint256 amount
    ) private view returns (uint256) {
        // get the vault token
        address vaultToken = assetManager.getTokenVault(token);
        // convert amount to shares
        uint256 sharesRequired = IERC4626(vaultToken).convertToShares(amount);
        return sharesRequired;
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------
    function getLoanParticipator(
        uint256 loanId,
        address depositor
    ) public view returns (LoanParticipator memory) {
        return loanParticipators[loanId][depositor];
    }

    function getLoan(uint256 loanId) public view returns (Loan memory) {
        return loans[loanId];
    }

    function getLoanTermAllocated(
        uint256 loanId,
        uint256 termId
    ) public view returns (bool) {
        return loanTermAllocated[loanId][termId];
    }
}
