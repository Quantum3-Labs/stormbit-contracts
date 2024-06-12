pragma solidity ^0.8.21;

import {ILendingTerms} from "./interfaces/ILendingTerms.sol";
import {IGovernable} from "./interfaces/IGovernable.sol";
import {ILenderRegistry} from "./interfaces/ILenderRegistry.sol";

/// @author Quantum3 Labs
/// @title Stormbit Lending Manager
/// @notice entrypoint for all lender and lending terms operations

contract StormbitLendingManager is IGovernable, ILendingTerms, ILenderRegistry {
    address public governor;

    mapping(address => bool) public registeredLenders;
    mapping(uint256 => LendingTerm) public lendingTerms;

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
        delete lendingTerms[id];
        emit LendingTermRemoved(id);
    }

    function _validLendingTerm(uint256 id) internal view returns (bool) {
        return lendingTerms[id].owner != address(0);
    }
}
