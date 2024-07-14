// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IHooks} from "../../hooks/IHooks.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager Interface
/// TODO split into different interfaces according to funcionality
interface ILendingManager {
    struct Balances {
        uint256 available; // available for tracking disposable shares
        Checkpoints.Trace224 profit;
        Checkpoints.Trace224 shares; // shares is weight but without profit
    }

    struct LendingTerm {
        address owner;
        uint256 comission; // TODO add balances and other ERC4626 custom fields
        uint256 nonZeroTokenBalanceCounter; // track non zero token counter
        IHooks hooks;
        mapping(address vaultToken => Balances balances) termBalances; // total shares controlled by the term owner
        mapping(address user => mapping(address vaultToken => Checkpoints.Trace224)) userSharesCheckpoints;
    }

    struct LendingTermMetadata {
        address owner;
        uint256 comission;
        IHooks hooks;
    }

    event LendingTermCreated(uint256 indexed termId, address lender, uint256 comission, address hooks);

    event LendingTermRemoved(uint256 indexed termId);

    event DepositToTerm(uint256 indexed termId, address indexed user, address indexed token, uint256 shares);

    event WithdrawFromTerm(uint256 indexed termId, address indexed user, address indexed token, uint256 shares);

    event FreezeShares(uint256 indexed termId, address indexed token, uint256 shares);

    event UnfreezeShares(uint256 indexed termId, address indexed token, uint256 shares);

    event DistributeProfit(uint256 indexed termId, address indexed token, uint256 profit);

    function createLendingTerm(uint256 comission, IHooks hooks) external returns (uint256);

    function removeLendingTerm(uint256 termId) external;

    function depositToTerm(uint256 termId, address token, uint256 shares) external;

    function withdrawFromTerm(uint256 termId, address token, uint256 requestedDecrease) external;

    function freezeTermShares(uint256 termId, uint256 shares, address token) external;

    function unfreezeTermShares(uint256 termId, uint256 shares, address token) external;

    function distributeProfit(
        uint256 termId,
        address token,
        uint256 profit,
        uint256 shares,
        uint256 ownerProfit,
        uint256 executionTimestamp
    ) external;

    function getLendingTerm(uint256 termId) external returns (LendingTermMetadata memory);

    function getTermFreezedShares(uint256 termId, address token) external view returns (uint256);

    function getLendingTermBalances(uint256 termId, address token) external view returns (uint256, uint256, uint256);
}
