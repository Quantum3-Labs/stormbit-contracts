pragma solidity ^0.8.21;

import {IHooks} from "../../hooks/IHooks.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager Interface
/// TODO split into different interfaces according to funcionality
interface ILendingManager {
    struct Shares {
        uint256 available;
        uint256 total;
        uint256 profit;
    }

    struct LendingTerm {
        address owner;
        uint256 comission; // TODO add balances and other ERC4626 custom fields
        IHooks hooks;
        mapping(uint256 termId => mapping(address vaultToken => Shares shares)) termOwnerShares; // total shares controlled by the term owner
        mapping(uint256 termId => uint256 nonZeroTokenBalanceCounter) termNonZeroTokenCounter; // track non zero token counter
    }

    struct LendingTermMetadata {
        address owner;
        uint256 comission; // TODO add balances and other ERC4626 custom fields
        IHooks hooks;
    }

    event LendingTermCreated(
        uint256 indexed id,
        address lender,
        uint256 comission
    );

    event LendingTermRemoved(uint256 indexed id);

    event LenderClaimLoanProfit(
        uint256 indexed termId,
        uint256 indexed loanId,
        address indexed token,
        uint256 profit
    );

    event BorrowerWithdraw(
        address indexed borrower,
        address indexed token,
        uint256 assets
    );

    event DepositToTerm(
        uint256 indexed id,
        address indexed user,
        address indexed token,
        uint256 shares
    );

    event WithdrawFromTerm(
        uint256 indexed id,
        address indexed user,
        address indexed token,
        uint256 shares
    );

    event FreezeSharesOnTerm(
        uint256 indexed termId,
        address indexed token,
        uint256 shares
    );

    function createLendingTerm(
        uint256 comission,
        IHooks hooks
    ) external returns (uint256);

    function removeLendingTerm(uint256 id) external;

    function borrowerWithdraw(
        address borrower,
        address token,
        uint256 assets
    ) external;

    function lenderClaimLoanProfit(
        uint256 termId,
        uint256 loanId,
        address token
    ) external;

    function depositToTerm(
        uint256 termId,
        address token,
        uint256 shares
    ) external;

    function withdrawFromTerm(
        uint256 termId,
        address token,
        uint256 requestedDecrease
    ) external;

    function freezeTermShares(
        uint256 termId,
        uint256 shares,
        address token
    ) external;

    function getLendingTerm(
        uint256 id
    ) external returns (LendingTermMetadata memory);

    function getTotalSharesOnTerm(
        uint256 termId,
        address token
    ) external view returns (uint256);

    function getTermFreezedShares(
        uint256 termId,
        address token
    ) external view returns (uint256);

    function getTermProfit(
        uint256 termId,
        address token
    ) external returns (uint256);

    function getDisposableSharesOnTerm(
        uint256 termId,
        address token
    ) external view returns (uint256);

    function getUserTotalDelegatedShares(
        address user,
        address token
    ) external view returns (uint256);
}
