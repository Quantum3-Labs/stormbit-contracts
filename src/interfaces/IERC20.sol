pragma solidity ^0.8.21;

import {IERC20 as OZIERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20 is OZIERC20 {
    function symbol() external view returns (string memory);
}
