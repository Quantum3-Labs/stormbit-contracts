// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/test.sol";
import "../src/agreements/BaseAgreement.sol";
import "./MockToken.t.sol";

contract BaseAgreementTest is Test {
    MockToken public token;
    BaseAgreement public agreement;
    address owner = makeAddr("owner");

    function setUp() public {
        agreement = new BaseAgreement();
    }

    function testDeployment() public {
        assertEq(address(agreement.paymentToken()), address(token));
    }
}
