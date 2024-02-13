pragma solidity ^0.8.21;

import "../AgreementBase.sol";
import {StormBitCore} from "../StormBitCore.sol";
import {StormBitLending} from "../StormBitLending.sol";

import {IStormBitLending} from "../interfaces/IStormBitLending.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseAgreement is AgreementBase {
    address private borrower;
    address public token;

    mapping(address => uint256) public userAllocation;
    mapping(address => uint256) public startTime;

    event ETHReceived(uint256 amount);

    constructor(address _token) public {
        borrower = msg.sender;
        token = _token;
    }

    // 1. funds are received into this contract
    // 2. user withdraws this funds
    function afterLoan(bytes memory) external override returns (bool) {
        startTime[msg.sender] = block.timestamp;
        IERC20(token).transfer(msg.sender, userAllocation[msg.sender]);
        userAllocation[borrower] = 0;
    }

    function nextPayment() public view override returns (uint256, uint256) {
        uint256 dueTime = startTime[borrower] + 10 days; // @note - 10 days after deposit of collateral
        return (_amounts[_paymentCount], dueTime);
    }

    function withdraw(uint256 amount) public {
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {
        emit ETHReceived(msg.value);
    }
}
