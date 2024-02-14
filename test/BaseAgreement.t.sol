// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/test.sol";
import "../src/agreements/BaseAgreement.sol";
import "./MockToken.t.sol";

contract BaseAgreementTest is Test {
    MockToken public mockToken;
    BaseAgreement public agreement;
    address owner = makeAddr("owner");

    function setUp() public {
        agreement = new BaseAgreement();
        mockToken = new MockToken();
    }

    function initAgreement() public {
        agreement.initialize(
            abi.encode(
                1000,
                address(mockToken),
                [100, 200, 300],
                [20 days, 10 days, 5 days]
            )
        );

        assertEq(address(agreement.paymentToken()), address(mockToken));

    }
}
