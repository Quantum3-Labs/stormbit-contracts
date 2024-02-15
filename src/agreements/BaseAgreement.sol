pragma solidity ^0.8.21;

import "../AgreementBedrock.sol";
import {StormBitCore} from "../StormBitCore.sol";
import {StormBitLending} from "../StormBitLending.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseAgreement is AgreementBedrock {
    mapping(address => uint256) public borrowBalance;
    mapping(address => uint256) public startTime;
    mapping(address => bool) public isBorrower;

    function initialize(bytes memory initData) external override initializer {
        (
            uint256 lateFee,
            address borrower,
            address lender,
            address PaymentToken,
            uint256[] memory amounts,
            uint256[] memory times
        ) = abi.decode(initData, (uint256, address, address, address, uint256[], uint256[]));
        _lateFee = lateFee;
        _lender = lender;
        _borrower = borrower;
        _paymentToken = PaymentToken;
        _amounts = amounts;
        _times = times;
        _deployer = msg.sender;
    }

    function lateFee() public view override returns (uint256) {
        return _lateFee;
    }

    function paymentToken() public view override returns (address) {
        return _paymentToken;
    }

    function nextPayment() public view override returns (uint256, uint256) {
        return (_amounts[_paymentCount], _times[_paymentCount]);
    }

    /*
     * @notice - Borrower pays back the loan
     */
    function payBack() public override returns (bool) {
        // check if deadline has passed and apply fee on borrower
        (uint256 amount,) = nextPayment();
        uint256 fee = penalty();
        IERC20(_paymentToken).transfer(address(this), amount + fee);
        _paymentCount++;
        return true;
    }

    /**
     * @notice - Borrower sends loan amount to his wallet
     */
    function withdraw() public override {
        require(borrowBalance[msg.sender] > 0, "No funds to withdraw");
        IERC20(_paymentToken).transfer(msg.sender, borrowBalance[msg.sender]);
    }

    function getPaymentDates() public view override returns (uint256[] memory, uint256[] memory) {
        return (_amounts, _times);
    }

    function penalty() public view override returns (uint256) {
        (uint256 amount, uint256 time) = nextPayment();
        if (_hasPenalty || time < block.timestamp) {
            return (_lateFee);
        }
        return 0;
    }

    /**
     * @notice - Agreement should receive allocation of funds
     * @dev - This function is called by the StormBitLending.executeLoan() function
     */
    receive() external payable {
        borrowBalance[msg.sender] += msg.value;
    }
}
