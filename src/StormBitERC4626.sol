// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// an ERC4626 with an underlying asset and with a fee for each deposit, fee is credited to StormBit Core

contract StormBitERC4626 is ERC4626 {
    IERC20 private _underlyingToken;

    constructor(IERC20 underlyingToken) ERC4626(underlyingToken) ERC20("StormBitERC4626", "STB4626") {
        _underlyingToken = underlyingToken;
        _mint(msg.sender, 10000000);
    }
}
