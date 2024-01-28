// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StormBitERC4626 is ERC4626 {
    IERC20 private _underlyingToken;
    address private token;

    constructor(IERC20 underlyingToken) 
        ERC4626(underlyingToken)  
        ERC20("StormBit", "STB")  
    {
        _underlyingToken = underlyingToken;
        _mint(msg.sender, 10000000); 
    }
}
