// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC20 as OzIERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20 is OzIERC20 {
    function symbol() external view returns (string memory);
}
