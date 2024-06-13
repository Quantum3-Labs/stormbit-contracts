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
    mapping(uint256 => Loan) public loans;

    constructor(address _governor) {
        governor = _governor;
    }

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
            terms: new ILendingTerms.LendingTerm[](0),
            status: LoanStatus.Pending
        });

        emit LoanRequested(loanId, msg.sender, token, amount, deadline);
        return loanId;
    }

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
        // tell lending manager, use lending manager to approve required amount of token to borrower

        // withdraw by asset manager
        assetManager.withdraw(loan.token, loan.amount);

        loans[loanId].status = LoanStatus.Active;
    }

    function repay() public {}

    function allocateTerm() public onlyLender {
        // todo: do we need to handle case where allocate fund more than requested fund
    }

    // -----------------------------------------
    // -------- PUBLIC GETTER FUNCTIONS --------
    // -----------------------------------------

    function repay(uint256 loanId) external override {}
}
