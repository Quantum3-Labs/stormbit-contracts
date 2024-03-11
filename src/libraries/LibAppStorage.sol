//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibDiamond} from "../libraries/LibDiamond.sol";

struct AppStorage {
    bool initialized; // Flag indicating if the contract has been initialized
    address governor; // Address of the contract owner
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}
