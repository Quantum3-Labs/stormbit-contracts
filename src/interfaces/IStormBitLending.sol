// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

interface IStormBitLending {
    struct InitParams {
        uint256 creditScore;
        uint256 maxAmountOfStakers;
        uint256 votingQuorum; //  denominated in 100
        uint256 maxPoolUsage;
        uint256 votingPowerCoolDown;
        uint256 initAmount;
        address initToken; //  initToken has to be in supportedAssets
        address[] supportedAssets;
    }

    struct LoanRequestParams {
        uint256 amount;
        address token;
        address strategy;
        bytes strategyCalldata;
    }

    function initialize(InitParams memory params, address _firstOwner) external;
}
