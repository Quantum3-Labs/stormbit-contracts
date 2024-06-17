pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Delegation Interface
/// TODO split into different interfaces according to funcionality
interface IDelegation {
    struct Shares {
        uint256 disposableAmount;
        uint256 totalAmount;
        uint256 profit;
    }

    event DepositToTerm(
        uint256 indexed id,
        address indexed user,
        address indexed vaultToken,
        uint256 shares
    );

    event WithdrawFromTerm(
        uint256 indexed id,
        address indexed user,
        address indexed vaultToken,
        uint256 shares
    );

    event FreezeSharesOnTerm(
        uint256 indexed id,
        address indexed user,
        address indexed vaultToken,
        uint256 shares
    );

    event UnfreezeSharesOnTerm(
        uint256 indexed id,
        address indexed user,
        address indexed vaultToken,
        uint256 shares
    );

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

    // function freezeSharesOnTerm(
    //     uint256 termId,
    //     address vaultToken,
    //     address depositor,
    //     uint256 freezeAmount
    // ) external;

    // function unfreezeSharesOnTerm(
    //     uint256 termId,
    //     address vaultToken,
    //     address depositor,
    //     uint256 unfreezeAmount
    // ) external;
}
