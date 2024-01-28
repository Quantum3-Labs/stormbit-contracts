// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./interfaces/IStormBitLending.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// - StormBitLending: implementation contract to be used when creating new lending pools.
//     - has a bunch of setters and getters that are only owner.
//     - has a approve loan function that is only available for people with voting power. ( can use a tweaked governance here )

contract StormBitLending is ReentrancyGuard {
    address public token;
    address public launcher;

    constructor(address _token, uint8 _maxAmountOfStakers, address _launcher) {
        require(_token != address(0), "StormBitLending: token address cannot be 0");
        require(_launcher != address(0), "StormBitLending: pool manager address cannot be 0");

        token = _token;
        launcher = _launcher;
    }
}
