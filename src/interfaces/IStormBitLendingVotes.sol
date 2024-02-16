pragma solidity ^0.8.21;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface IStormBitLendingVotes is IVotes {
    function mint(address to, uint256 amount) external;

    function delegate(address from, address to) external;

    function initialize(address stormBitLending) external;
}
