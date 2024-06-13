pragma solidity ^0.8.21;

import "forge-std/test.sol";

contract TestUtils is Test {
    address governor = makeAddr("governor");
    address depositor1 = vm.addr(1);
    address depositor2 = vm.addr(2);
    address depositor3 = vm.addr(3);

    address lender1 = vm.addr(4);
    address lender2 = vm.addr(5);
    address lender3 = vm.addr(6);

    uint256 initialTokenBalance = 10_000;
}
