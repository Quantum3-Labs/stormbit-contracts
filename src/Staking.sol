// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./interfaces/IStaking.sol";

abstract contract Staking is IStaking {
    address public token;

    uint256 public minimumStake;

    address[] public borrowers;

    mapping(address => Loans.Lender) public loans;

    function stake(uint256 _tokens) external override returns (uint256) {
        require(_tokens > 0, "Staking: zero tokens");
        require(_tokens >= minimumStake, "Staking: tokens less than minimum stake");
    }
}
