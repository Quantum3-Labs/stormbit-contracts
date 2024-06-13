pragma solidity ^0.8.21;

import "forge-std/test.sol";

contract TestUtils is Test {
    // first account in anvil
    address governor = makeAddr("governor");
    address depositor = vm.addr(1);
}
