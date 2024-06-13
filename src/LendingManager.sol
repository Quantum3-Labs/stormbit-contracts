pragma solidity ^0.8.21;

import {ILendingTerms} from "./interfaces/ILendingTerms.sol";
import {IGovernable} from "./interfaces/IGovernable.sol";
import {ILenderRegistry} from "./interfaces/ILenderRegistry.sol";
import {StormbitAssetManager} from "./AssetManager.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager
/// @notice entrypoint for all lender and lending terms operations

// todo: use custom error
contract StormbitLendingManager is IGovernable, ILendingTerms, ILenderRegistry {
    address public governor;
    StormbitAssetManager assetManager;
    mapping(address => bool) public registeredLenders;
    mapping(uint256 => LendingTerm) public lendingTerms;
    // total disporsed shares to a lending term
    mapping(uint256 termId => mapping(address vaultToken => uint256 sharesAmount)) termTokenAllowances;
    // track user total delegated shares to different term
    mapping(address user => mapping(address vaultToken => uint256 delegatedShares)) userTotalDelegatedShares;
    // track user delegated shares to a term (static)
    mapping(uint256 termId => mapping(address user => mapping(address vaultToken => uint256 sharesAmount))) termUserDelegatedShares;
    // track user delegated shares to a term (dynamic)
    mapping(uint256 termId => mapping(address user => mapping(address vaultToken => uint256 sharesAmount))) termDynamicUserDelegatedShares;
    // track who delegated to the term
    mapping(uint256 termId => mapping(address vaultToken => address[] user)) termDelegatedUsers;
    // locked shares, the shares want lent out
    mapping(address user => mapping(address vaultToken => uint256 sharesAmount)) userFreezedShares;

    constructor(address _governor) {
        governor = _governor;
    }

    modifier onlyGovernor() {
        require(msg.sender == governor, "StormbitAssetManager: not governor");
        _;
    }

    modifier onlyRegisteredLender() {
        require(
            registeredLenders[msg.sender],
            "StormbitLendingManager: not registered lender"
        );
        _;
    }

    function isRegistered(address lender) public view override returns (bool) {
        return registeredLenders[lender];
    }

    function register() public override {
        registeredLenders[msg.sender] = true;
    }

    function createLendingTerm(
        uint256 comission
    ) public override onlyRegisteredLender returns (uint256) {
        uint256 id = uint256(keccak256(abi.encode(msg.sender, comission)));
        require(
            !_validLendingTerm(id),
            "StormbitLendingManager: lending term already exists"
        );
        lendingTerms[id] = LendingTerm(msg.sender, comission);
        emit LendingTermCreated(id, msg.sender, comission);
    }

    function removeLendingTerm(
        uint256 id
    ) public override onlyRegisteredLender {
        require(
            _validLendingTerm(id),
            "StormbitLendingManager: lending term does not exist"
        );
        // todo: what if there are delegated shares to the term
        delete lendingTerms[id];
        emit LendingTermRemoved(id);
    }

    /// @dev allow lender to delegate shares to a lending term
    /// @param termId id of the lending term
    /// @param vaultToken address of the vault token
    /// @param sharesAmount amount of shares to delegate
    function increaseDelegateToTerm(
        uint256 termId,
        address vaultToken,
        uint256 sharesAmount
    ) public {
        require(
            _validLendingTerm(termId),
            "StormbitLendingManager: lending term does not exist"
        );
        // get current delegated shares to the term
        uint256 currentDelegatedShares = userTotalDelegatedShares[msg.sender][
            vaultToken
        ];
        // get user shares in the vault
        uint256 userShares = assetManager.getUserShares(vaultToken, msg.sender);
        // check if the user has enough shares
        require(
            userShares >= currentDelegatedShares + sharesAmount,
            "StormbitLendingManager: not enough shares"
        );
        // update user total delegated shares, prevent scenario delegate more than user has
        userTotalDelegatedShares[msg.sender][vaultToken] += sharesAmount;
        // update term total disposable shares (allowance)
        termTokenAllowances[termId][vaultToken] += sharesAmount;
        if (termUserDelegatedShares[termId][msg.sender][vaultToken] <= 0) {
            // this is the first time the user is delegating to the term
            // update the list of users who delegated to the term
            termDelegatedUsers[termId][vaultToken].push(msg.sender);
        }
        // update the amount of shares delegated to the term by the user
        termUserDelegatedShares[termId][msg.sender][vaultToken] += sharesAmount;
        termDynamicUserDelegatedShares[termId][msg.sender][
            vaultToken
        ] += sharesAmount;

        // todo: approve the asset manager to transfer the shares

        emit IncreaseDelegateSharesToTerm(
            termId,
            msg.sender,
            vaultToken,
            sharesAmount
        );
    }

    function decreaseDelegateToTerm(
        uint256 termId,
        address vaultToken,
        uint256 requestedDecrease
    ) public {
        require(
            _validLendingTerm(termId),
            "StormbitLendingManager: lending term does not exist"
        );
        // get current delegated shares to the term
        uint256 currentDelegatedShares = termUserDelegatedShares[termId][
            msg.sender
        ][vaultToken];
        uint256 freezedShares = userFreezedShares[msg.sender][vaultToken];
        uint256 dynamicDelegatedShares = termDynamicUserDelegatedShares[termId][
            msg.sender
        ][vaultToken];

        require(
            currentDelegatedShares >= requestedDecrease,
            "StormbitLendingManager: insufficient delegated shares"
        );
        require(
            dynamicDelegatedShares - freezedShares >= requestedDecrease,
            "StormbitLendingManager: insufficient unfreezed shares"
        );
        termUserDelegatedShares[termId][msg.sender][
            vaultToken
        ] -= requestedDecrease;
        termDynamicUserDelegatedShares[termId][msg.sender][
            vaultToken
        ] -= requestedDecrease;
        userTotalDelegatedShares[msg.sender][vaultToken] -= requestedDecrease;
        termTokenAllowances[termId][vaultToken] -= requestedDecrease;

        emit DecreaseDelegateSharesToTerm(
            termId,
            msg.sender,
            vaultToken,
            requestedDecrease
        );
    }

    function _validLendingTerm(uint256 id) internal view returns (bool) {
        return lendingTerms[id].owner != address(0);
    }
}
