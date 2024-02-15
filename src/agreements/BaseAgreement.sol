pragma solidity ^0.8.21;

import "../AgreementBedrock.sol";
import {StormBitCore} from "../StormBitCore.sol";
import {StormBitLending} from "../StormBitLending.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseAgreement is AgreementBedrock {
    mapping(address => uint256) public borrowerAllocation;
    mapping(address => uint256) public startTime;

    function initialize(bytes memory initData) external override initializer {
        (
            uint256 lateFee,
            address PaymentToken,
            uint256[] memory amounts,
            uint256[] memory times
        ) = abi.decode(initData, (uint256, address, uint256[], uint256[]));
        _lateFee = lateFee;
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
        (uint256 amount, ) = nextPayment();
        uint256 fee = penalty();
        IERC20(_paymentToken).transfer(address(this), amount + fee);
        _paymentCount++;
        return true;
    }

    function beforeLoan(bytes memory) external override returns (bool) {
        return true;
    }

    // 1. funds are received into this contract
    // 2. user withdraws this funds
    function afterLoan(bytes memory) external override returns (bool) {
        startTime[msg.sender] = block.timestamp;
        withdraw();
        borrowerAllocation[msg.sender] = 0;
    }

    function withdraw() public override {
        require(borrowerAllocation[msg.sender] > 0, "No funds to withdraw");
        IERC20(_paymentToken).transfer(
            msg.sender,
            borrowerAllocation[msg.sender]
        );
    }

    function getPaymentDates()
        public
        view
        override
        returns (uint256[] memory, uint256[] memory)
    {
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
    receive() external payable {}
}
