// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/test.sol";
import {Staking} from "../src/Staking.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

contract StakingTest is Test {
    Staking public staking;
    MockERC20 public token;

    function setUp() public {
        token = new MockERC20();
        staking = new Staking(address(token), 100, 100);
    }
}
