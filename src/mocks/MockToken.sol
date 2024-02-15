// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("StormBitToken", "SBT") {
        _mint(msg.sender, 200000);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
