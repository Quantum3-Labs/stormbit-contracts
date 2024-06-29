// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC4626 as OzIERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IERC4626 is OzIERC4626 {
    function decimals() external view returns (uint8);
}
