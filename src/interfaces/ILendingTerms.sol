pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Lending Terms Interface
/// TODO split into different interfaces according to funcionality
interface ILendingTerms {
    struct LendingTerm {
        address owner;
        uint256 comission; // TODO add balances and other ERC4626 custom fields
    }
    event LendingTermCreated(
        uint256 indexed id,
        address lender,
        uint256 comission
    );
    event LendingTermRemoved(uint256 indexed id);
    event IncreaseDelegateSharesToTerm(
        uint256 indexed id,
        address indexed user,
        address indexed vaultToken,
        uint256 shares
    );
    event DecreaseDelegateSharesToTerm(
        uint256 indexed id,
        address indexed user,
        address indexed vaultToken,
        uint256 shares
    );

    function createLendingTerm(uint256 comission) external returns (uint256);

    function removeLendingTerm(uint256 id) external;
}
