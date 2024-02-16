pragma solidity ^0.8.21;

import "../AgreementBedrock.sol";
import {StormBitCore} from "../StormBitCore.sol";
import {StormBitLending} from "../StormBitLending.sol";

/**
 * @title SimpleAgreement
 * @author Q3 Labs
 * @notice For NFT please override inialitization
 */
contract SimpleAgreement is AgreementBedrock {
    function _beforeLoan() internal override {
        // do nothing, in NFT we transfer the token here
    }

    function _afterLoan() internal override {
        // do nothing in NFT we transfer token back
    }
}
