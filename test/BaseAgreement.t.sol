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

    function testInitAgreement() public {
        // Ensuring correct data encoding for the initialize call
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;
        uint256[] memory times = new uint256[](2);
        times[0] = 1000;
        times[1] = 2000;

        bytes memory initData = abi.encode(
            1000, // lateFee
            address(mockToken), // PaymentToken address
            amounts,
            times
        );
    
        agreement.initialize(initData);

        // Assertions to verify initialization was successful
        assertEq(address(agreement.paymentToken()), address(mockToken));
        assertEq(agreement.lateFee(), 1000);
        // Add more assertions as necessary to verify the amounts and times
    }
}
