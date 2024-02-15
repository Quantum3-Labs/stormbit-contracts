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
        bytes memory initData = abi.encode(
            1000, // lateFee
            address(mockToken),             // PaymentToken address
            [200, 100, 50],
            [2 days, 3 days, 4 days]
        );

        address agreementImpl = address(new BaseAgreement());
        bytes memory agreementData = abi.encodeWithSelector(BaseAgreement.initialize.selector, initData);
        address agreementProxy = address(new ERC1967Proxy(agreementImpl, agreementData));
        agreement = BaseAgreement(payable(agreementProxy));
    }

    function testInitAgreement() public {
        assertEq(address(agreement.paymentToken()), address(mockToken));
        assertEq(agreement.lateFee(), 1000);
        // check next payment
        // (uint256 amount, uint256 time) = agreement.nextPayment();
        // assertEq(agreement._amounts(1), 200);

        
        
    }
}
