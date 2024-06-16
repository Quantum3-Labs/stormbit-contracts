pragma solidity ^0.8.21;

import {ILendingTerms} from "./interfaces/managers/lending/ILendingTerms.sol";
import {ILoanRequest} from "./interfaces/managers/loan/ILoanRequest.sol";
import {ILoanManager} from "./interfaces/managers/loan/ILoanManager.sol";
import {ILoanManagerView} from "./interfaces/managers/loan/ILoanManagerView.sol";
import {IAllocation} from "./interfaces/managers/loan/IAllocation.sol";
import {IERC4626} from "./interfaces/token/IERC4626.sol";
import {IGovernable} from "./interfaces/utils/IGovernable.sol";
import {IInitialize} from "./interfaces/utils/IInitialize.sol";
import {StormbitAssetManager} from "./AssetManager.sol";
import {StormbitLendingManager} from "./LendingManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @author Quantum3 Labs
/// @title Stormbit Loan Manager
/// @notice entrypoint for loan related operations

// todo: be aware of denial of service on for loop
contract StormbitLoanManager is
    IGovernable,
    IInitialize,
    ILoanManager,
    ILoanManagerView,
    ILoanRequest,
    IAllocation,
    Ownable
{
    address private _governor;
    StormbitLendingManager public lendingManager;
    uint256 public loanCounter;
    StormbitAssetManager public assetManager;

    mapping(uint256 loanId => Loan loan) public loans;
    mapping(uint256 loanId => ILendingTerms.LendingTerm[] terms)
        public loanTerms;
    mapping(uint256 loanId => mapping(uint256 termId => uint256 allocatedAmount))
        public termAllocatedAmount;
    mapping(uint256 loanId => mapping(uint256 termId => bool isAllocated))
        public loanTermAllocated;
    mapping(uint256 loanId => address[] participators)
        public participatorsAddresses;
    mapping(uint256 loanId => mapping(address depositor => LoanParticipator loanParticipator))
        public loanParticipators;

    constructor(address initialGovernor, address owner) Ownable(owner) {
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

    function initialize(
        address assetManagerAddr,
        address lendingManagerAddr
    ) public override onlyOwner {
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

        // todo: change the fixed rate
        // 5% interest rate
        uint256 repayAmount = amount + (amount * 5) / 100;

        loans[loanId] = Loan({
            borrower: msg.sender,
            token: token,
            repayAmount: repayAmount,
            sharesRequired: sharesRequired,
            sharesAllocated: 0,
            deadline: deadline,
            status: LoanStatus.Pending
        });

        emit LoanRequested(loanId, msg.sender, token, amount);
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
        address tokenVault = assetManager.getTokenVault(loan.token);
        // withdraw by asset manager
        assetManager.borrowerWithdraw(
            loanId,
            loan.borrower,
            tokenVault,
            participatorsAddresses[loanId]
        );
        loans[loanId].status = LoanStatus.Active;

        emit LoanExecuted(loanId, loan.borrower, loan.token, loan.repayAmount);
    }

    /// @dev allow anyone to repay the loan, not restricted to borrower
    /// @param loanId id of the loan
    // todo: allow repay partially?
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
        // loop through all term allocated to the loan
        uint256 loanTotalShares = loan.sharesRequired;
        uint256 remainingRepayment = loan.repayAmount;

        for (uint256 i = 0; i < loanTerms[loanId].length; i++) {
            ILendingTerms.LendingTerm memory term = loanTerms[loanId][i];
            //get
            // get the weight of term occupied in the loan
            uint256 termId = uint256(
                keccak256(abi.encode(term.owner, term.comission))
            );
            uint256 termWeight = termAllocatedAmount[loanId][termId];
            // see a term funded % in loan
            uint256 termFundedPercent = (termWeight * 100) / loanTotalShares;
            // calculate the fund to be distributed to the term
            uint256 fund = (loan.repayAmount * termFundedPercent) / 100;
            // from fund calculate the commission
            uint256 commission = (fund * term.comission) / 10000;
            // distribute the fund to the term owner
            assetManager.depositFrom(
                loan.token,
                commission,
                msg.sender,
                term.owner
            );
            remainingRepayment = remainingRepayment - commission;
        }

        // convert repayAmount to shares
        uint256 repayAmountShares = assetManager.convertToShares(
            loan.token,
            remainingRepayment
        );

        // distribute the remaining to the depositor
        // loop through the loan participators
        address[] memory participators = participatorsAddresses[loanId];
        // calculate how much each participant earn
        // todo: do some safety check
        uint256 eachParticipantEarn = repayAmountShares / participators.length;
        // todo: in this case the platform ot making money, because the interest are distributed to depositor
        for (uint256 i = 0; i < participators.length; i++) {
            LoanParticipator memory participator = loanParticipators[loanId][
                participators[i]
            ];
            // get the shares of the participator
            uint256 shares = participator.shares;
            // get the  token
            address token = participator.token;
            // get the amount of token to repay
            uint256 amount = assetManager.convertToAssets(
                token,
                eachParticipantEarn
            );
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

        // todo: if allow partial repayment, update the loan status when totally repaid, otherwise can just set it as done
        loans[loanId].status = LoanStatus.Repaid;
        emit LoanRepaid(loanId, msg.sender);
    }

    /// @dev enable the lender to allocate certain term for the loan, until the loan is fully allocated
    /// @param loanId id of the loan
    /// @param termId id of the term
    function allocateTerm(
        uint256 loanId,
        uint256 termId
    ) public override onlyLender {
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
        address tokenVault = assetManager.getTokenVault(loan.token);
        // check if term capable to fund the loan
        require(
            lendingManager.getDisposableSharesOnTerm(termId, tokenVault) > 0,
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

    /// @dev allow lender to allocate fund on the loan, but only when the term is already allocated
    /// @param loanId id of the loan
    /// @param termId id of the term
    /// @param amount amount of shares to allocate
    function allocateFundOnLoan(
        uint256 loanId,
        uint256 termId,
        uint256 amount
    ) public override onlyLender {
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
            loan.sharesAllocated + amount <= loan.sharesRequired,
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
            loan.sharesAllocated += propotionToFund;
        }
        // update loan at storage level
        loans[loanId] = loan;
        termAllocatedAmount[loanId][termId] += amount;
        emit AllocatedFundOnLoan(loanId, termId, amount);
    }

    // -----------------------------------------
    // ----------- PRIVATE FUNCTIONS -----------
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
    function governor() public view override returns (address) {
        return _governor;
    }

    function getLoanParticipator(
        uint256 loanId,
        address depositor
    ) public view override returns (LoanParticipator memory) {
        return loanParticipators[loanId][depositor];
    }

    function getLoan(
        uint256 loanId
    ) public view override returns (Loan memory) {
        return loans[loanId];
    }

    function getLoanTermAllocated(
        uint256 loanId,
        uint256 termId
    ) public view override returns (bool) {
        return loanTermAllocated[loanId][termId];
    }
}
