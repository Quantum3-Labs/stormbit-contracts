pragma solidity ^0.8.21;

import "forge-std/test.sol";

contract TestUtils is Test {
    // first account in anvil
    address governor = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address depositor = vm.addr(1);
}
