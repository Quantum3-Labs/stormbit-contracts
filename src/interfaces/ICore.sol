pragma solidity 0.8.20;

import {IBase} from "./IBase.sol";

struct LendingPoolInitData {
    string name;
    uint256 creditScore;
    uint256 maxAmountOfStakers;
    uint256 votingQuorum;
    uint256 maxPoolUsage;
    uint256 votingPowerCoolDown;
    uint256 initAmount;
    address initToken;
    address[] supportedAssets;
    address[] supportedAgreements;
}

/// @dev core interface for Stormbit protocol
interface ICore is IBase {
    function createLendingPool(
        LendingPoolInitData memory initData
    ) external returns (uint256);
}
