// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is Test, ERC20 {
    constructor() ERC20("StormBit", "SB") {
        _mint(msg.sender, 200000);
    }
}
