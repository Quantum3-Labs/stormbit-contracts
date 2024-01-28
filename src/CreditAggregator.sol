// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./interfaces/IStormBit.sol";

// - StormBit Credit Aggregator : contract that will use chainlink functions to aggregate credit score data of users on chain.
//     - a contract that uses many chainlink functions scripts to aggregate data from different APIs
//     - this is called when the user submits a loan request. his aggregated credit scored gets stored in the contract and will be used when the loan is approve.

contract CreditAggregator {}
