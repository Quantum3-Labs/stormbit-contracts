// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/test.sol";
import "../src/agreements/BaseAgreement.sol";
import "./MockToken.t.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/AgreementBedrock.sol";

contract BaseAgreementTest is Test {
    MockToken public mockToken;
    BaseAgreement public agreement;
    AgreementBedrock public bedrock;
    address owner = makeAddr("owner");

    function setUp() public {
        mockToken = new MockToken();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 200;
        amounts[1] = 100;

        uint256[] memory times = new uint256[](2);
        times[0] = 2;
        times[1] = 3;
        bytes memory initData = abi.encode(
            1000, // lateFee
            address(mockToken), // PaymentToken address
            amounts,
            times
        );

        address agreementImpl = address(new BaseAgreement());
        bytes memory agreementData = abi.encodeWithSelector(BaseAgreement.initialize.selector, initData);
        address agreementProxy = address(new ERC1967Proxy(agreementImpl, agreementData));
        agreement = BaseAgreement(payable(agreementProxy));
    }

    function testInitAgreement() public {
        assertEq(address(agreement.paymentToken()), address(mockToken));
        assertEq(agreement.lateFee(), 1000);
        (uint256 amount, uint256 time) = agreement.nextPayment();
        assertEq(agreement._amounts(0), 200);
    }
}
