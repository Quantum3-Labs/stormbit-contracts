pragma solidity ^0.8.21;

import "../AgreementBedrock.sol";
import {StormBitCore} from "../StormBitCore.sol";
import {StormBitLending} from "../StormBitLending.sol";

contract SimpleAgreement is AgreementBedrock {
    function nextPayment() public view override returns (uint256, uint256) {
        return (_amounts[_paymentCount], _times[_paymentCount]);
    }

    function _beforeLoan() internal override {
        // do nothing
    }

    function _afterLoan() internal override {
        // do nothing
    }
}
