// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";

contract TestUtils is Test {
    uint16 public constant BASIS_POINTS = 10_000;

    address owner = makeAddr("owner");
    address governor = makeAddr("governor");
    address funder = makeAddr("funder");

    address depositor1 = vm.addr(1);
    address depositor2 = vm.addr(2);
    address depositor3 = vm.addr(3);

    address lender1 = vm.addr(4);
    address lender2 = vm.addr(5);
    address lender3 = vm.addr(6);

    address borrower1 = vm.addr(7);
    address borrower2 = vm.addr(8);
    address borrower3 = vm.addr(9);

    uint256 initialTokenBalance = 10_000;
    uint256 initialFundBalance = 10_000;
}
