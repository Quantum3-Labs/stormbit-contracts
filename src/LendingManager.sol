pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC4626} from "./interfaces/token/IERC4626.sol";
import {IGovernable} from "./interfaces/utils/IGovernable.sol";
import {IInitialize} from "./interfaces/utils/IInitialize.sol";
import {IHooks} from "./interfaces/hooks/IHooks.sol";
import {IAssetManager} from "./interfaces/managers/asset/IAssetManager.sol";
import {ILoanManager} from "./interfaces/managers/loan/ILoanManager.sol";
import {ILendingManager} from "./interfaces/managers/lending/ILendingManager.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager
/// @notice entrypoint for all lender and lending terms operations

contract StormbitLendingManager is
    Initializable,
    IGovernable,
    IInitialize,
    ILendingManager
{
    uint16 public constant BASIS_POINTS = 10_000;

    address private _governor;
    IAssetManager public assetManager;
    ILoanManager public loanManager;

    mapping(uint256 => ILendingManager.LendingTerm) public lendingTerms;
    mapping(uint256 termId => mapping(address user => mapping(address vaultToken => uint256 shares)))
        public termUserDelegatedShares; // total shares delegated by the depositor on term
    mapping(address user => mapping(address vaultToken => uint256 delegatedShares)) // track user total delegated shares
        public userTotalDelegatedShares;
    mapping(uint256 termId => mapping(uint256 loanId => mapping(address vaultToken => bool)))
        public lenderClaimedProfit; // mapping to track lender claim profit

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

    modifier onlyLoanManager() {
        require(
            msg.sender == address(loanManager),
            "StormbitLendingManager: not loan manager"
        );
        _;
    }

    modifier onlyTermOwner(uint256 termId) {
        require(
            lendingTerms[termId].owner == msg.sender,
            "StormbitLendingManager: not term owner"
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
        assetManager = IAssetManager(assetManagerAddr);
        loanManager = ILoanManager(loanManagerAddr);
    }

    /// @dev create a lending term
    /// @param comission comission rate
    /// @return id of the lending term
    function createLendingTerm(
        uint256 comission,
        IHooks hooks
    ) public override returns (uint256) {
        uint256 id = uint256(keccak256(abi.encode(msg.sender, address(hooks))));
        require(
            !_validLendingTerm(id),
            "StormbitLendingManager: lending term already exists"
        );
        lendingTerms[id].owner = msg.sender;
        lendingTerms[id].comission = comission;
        lendingTerms[id].hooks = hooks;

        emit LendingTermCreated(id, msg.sender, comission);
        return id;
    }

    /// @dev remove a lending term
    /// @param id id of the lending term
    function removeLendingTerm(uint256 id) public override onlyTermOwner(id) {
        require(
            _validLendingTerm(id),
            "StormbitLendingManager: lending term does not exist"
        );
        // if there are delegated shares, the term cannot be removed
        require(
            lendingTerms[id].termNonZeroTokenCounter[id] <= 0,
            "StormbitLendingManager: term has non zero token balance"
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
            _beforeDepositToTerm(termId, token, shares),
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
        // get user shares in the vault
        uint256 userShares = assetManager.getUserShares(token, msg.sender);
        // check if the user has enough shares
        require(
            userShares >= shares,
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
        LendingTerm storage term = lendingTerms[termId];

        uint256 termSharesBalance = term
        .termOwnerShares[termId][vaultToken].total;

        // check if the vault token term has 0 balance
        if (termSharesBalance <= 0) {
            term.termNonZeroTokenCounter[termId]++;
        }

        // update the amount of shares delegated to the term by the user
        termUserDelegatedShares[termId][msg.sender][vaultToken] += shares;
        // update user total delegated shares, prevent scenario delegate more than user has
        uint256 userCurrentTotalDelegatedShares = currentDelegatedShares +
            shares;
        userTotalDelegatedShares[msg.sender][
            vaultToken
        ] = userCurrentTotalDelegatedShares;

        // update term total disposable shares (allowance)
        term.termOwnerShares[termId][vaultToken].available += shares;
        term.termOwnerShares[termId][vaultToken].total += shares;

        emit DepositToTerm(termId, msg.sender, token, shares);
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

        LendingTerm storage term = lendingTerms[termId];

        // check how many percentage of shares are freezed on term
        uint256 freezedShares = term.termOwnerShares[termId][vaultToken].total -
            term.termOwnerShares[termId][vaultToken].available;
        uint256 freezedSharesPercentage = (freezedShares * BASIS_POINTS) /
            term.termOwnerShares[termId][vaultToken].total;
        // get the freezeAmount from disposable shares
        uint256 freezeAmount = (totalDelegatedShares *
            freezedSharesPercentage) / BASIS_POINTS;

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
        uint256 weight = (shares * BASIS_POINTS) /
            term.termOwnerShares[termId][vaultToken].total;
        // give user the profit
        uint256 profit = (term.termOwnerShares[termId][vaultToken].profit *
            weight) / BASIS_POINTS;

        term.termOwnerShares[termId][vaultToken].total -= shares;
        term.termOwnerShares[termId][vaultToken].available -= shares;
        term.termOwnerShares[termId][vaultToken].profit -= profit;

        // transfer shares back to user
        bool isSuccess = IERC4626(vaultToken).transfer(
            msg.sender,
            shares + profit
        );
        if (!isSuccess) {
            revert("StormbitLendingManager: failed to transfer shares");
        }

        // if term shares balance is 0, decrement the counter
        if (term.termOwnerShares[termId][vaultToken].total <= 0) {
            term.termNonZeroTokenCounter[termId]--;
        }

        emit WithdrawFromTerm(termId, msg.sender, token, shares);
    }

    /// @dev allow lender to claim the profit for loan, then add the remaining profit to term profit
    function lenderClaimLoanProfit(
        uint256 termId,
        uint256 loanId,
        address token
    ) public override {
        address vaultToken = assetManager.getVaultToken(token);
        // check if the profit has been claimed
        require(
            !lenderClaimedProfit[termId][loanId][vaultToken],
            "StormbitLendingManager: profit already claimed"
        );
        // get term owner
        address termOwner = lendingTerms[termId].owner;
        require(
            msg.sender == termOwner,
            "StormbitLendingManager: not term owner"
        );
        // get loan
        ILoanManager.Loan memory loan = loanManager.getLoan(loanId);
        require(
            loan.status == ILoanManager.LoanStatus.Repaid,
            "StormbitLendingManager: loan not repaid"
        );
        // term allocated on shares should > 0
        uint256 weight = loanManager.getTermAllocatedSharesOnLoan(
            loanId,
            termId,
            token
        );
        require(
            weight > 0,
            "StormbitLendingManager: term not allocated on loan"
        );

        LendingTerm storage term = lendingTerms[termId];
        // convert repay assets to shares
        uint256 repayShares = assetManager.convertToShares(
            token,
            loan.repayAssets
        );
        // calculate profit
        // calculate shares required, convert assets to shares
        uint256 sharesRequired = assetManager.convertToShares(
            token,
            loan.assetsRequired
        );
        uint256 profitShares = repayShares - sharesRequired;
        // calculate weight of term in shares / loan required shares
        uint256 termFundedPercent = (weight * BASIS_POINTS) / sharesRequired;
        // term owner profit shares
        uint256 termProfitShares = (profitShares * termFundedPercent) /
            BASIS_POINTS;
        // from term profit shares, get commission for term owner
        uint256 termOwnerProfitShares = (termProfitShares * term.comission) /
            10000;
        // calculate the remaining profit after term owner profit
        uint256 extraProfit = termProfitShares - termOwnerProfitShares;

        // update term profit
        term.termOwnerShares[termId][vaultToken].profit += extraProfit;
        // update disposable shares
        term.termOwnerShares[termId][vaultToken].available += weight;
        // update claimed status
        lenderClaimedProfit[termId][loanId][vaultToken] = true;

        // transfer profit shares to term owner
        bool isSuccess = IERC4626(vaultToken).transfer(
            termOwner,
            termOwnerProfitShares
        );
        if (!isSuccess) {
            revert("StormbitLendingManager: failed to transfer profit");
        }

        emit LenderClaimLoanProfit(
            termId,
            loanId,
            token,
            termOwnerProfitShares
        );
    }

    /// @dev freeze the shares on term when allocated fund to loan
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

        LendingTerm storage term = lendingTerms[termId];

        require(
            term.termOwnerShares[termId][vaultToken].available >= shares,
            "StormbitLendingManager: insufficient disposable shares"
        );
        term.termOwnerShares[termId][vaultToken].available -= shares;

        emit FreezeSharesOnTerm(termId, token, shares);
    }

    function borrowerWithdraw(
        address borrower,
        address token,
        uint256 assets
    ) public override onlyLoanManager {
        address vaultToken = assetManager.getVaultToken(token);
        // convert assets to shares
        uint256 shares = assetManager.convertToShares(token, assets);
        IERC4626(vaultToken).approve(address(assetManager), shares);
        assetManager.borrowerWithdraw(borrower, token, assets);
        emit BorrowerWithdraw(borrower, token, assets);
    }

    // -----------------------------------------
    // ---------- PRIVATE FUNCTIONS ------------
    // -----------------------------------------
    function _beforeDepositToTerm(
        uint256 termId,
        address token,
        uint256 shares
    ) private returns (bool) {
        IHooks hooks = lendingTerms[termId].hooks;
        // ! remove this
        if (address(hooks) == address(0) || address(hooks) == address(1)) {
            return true;
        }
        return hooks.beforeDepositToTerm(msg.sender, token, termId, shares);
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

    function getLendingTerm(
        uint256 id
    ) public view override returns (LendingTermMetadata memory) {
        return
            LendingTermMetadata(
                lendingTerms[id].owner,
                lendingTerms[id].comission,
                lendingTerms[id].hooks
            );
    }

    /// @dev get the owner's vault token disposable shares on a term
    function getDisposableSharesOnTerm(
        uint256 termId,
        address token
    ) public view override returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return
            lendingTerms[termId].termOwnerShares[termId][vaultToken].available;
    }

    function getTotalSharesOnTerm(
        uint256 termId,
        address token
    ) public view override returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return lendingTerms[termId].termOwnerShares[termId][vaultToken].total;
    }

    function getTermFreezedShares(
        uint256 termId,
        address token
    ) public view override returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return
            lendingTerms[termId].termOwnerShares[termId][vaultToken].total -
            lendingTerms[termId].termOwnerShares[termId][vaultToken].available;
    }

    function getTermProfit(
        uint256 termId,
        address token
    ) public view override returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return lendingTerms[termId].termOwnerShares[termId][vaultToken].profit;
    }

    function getUserTotalDelegatedShares(
        address user,
        address token
    ) public view override returns (uint256) {
        address vaultToken = assetManager.getVaultToken(token);
        return userTotalDelegatedShares[user][vaultToken];
    }
}
