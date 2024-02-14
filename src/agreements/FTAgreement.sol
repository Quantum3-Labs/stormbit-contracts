pragma solidity ^0.8.21;

import "../AgreementBase.sol";
import "../interfaces/IStormBitLending.sol";
import {StormBitCore} from "../StormBitCore.sol";
import {StormBitLending} from "../StormBitLending.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract FTAgreement is AgreementBase {
    StormBitCore stormbitCore;
    StormBitLending stormbitLending;

    uint256 public loanAmount;
    uint256 public collateralAmount;
    address public token;
    bytes agreementCalldata;

    mapping(address => bool) public requested;
    mapping(address => uint256) public depositTimes;
    mapping(address => uint256) public collateralBalances;

    constructor(StormBitCore _stormbitCore, StormBitLending _stormbitLending, uint256 _collateralAmount) {
        stormbitCore = _stormbitCore;
        stormbitLending = _stormbitLending;
        collateralAmount = _collateralAmount;
    }

    modifier onlyLender() {
        require(msg.sender == address(stormbitLending), "StormBitLending: not self");
        _;
    }

    // Before Loan requirements :
    // KYC Verified already checked on requestLoan
    // Collateral deposit
    function beforeLoan(bytes memory) external override returns (bool) {
        if (!requested[msg.sender]) {
            revert("Loan not requested yet");
        }
    }

    // After Loan requirements :
    // return the collateral deposit to the user.
    function afterLoan(bytes memory) external override onlyLender returns (bool) {
        //@audit -- onlyStormbitLender can call this function
        uint256 collateral = collateralBalances[msg.sender];
        require(collateral > 0, "No collateral to return");
        IERC20(token).transferFrom(address(stormbitLending), msg.sender, collateral);
        collateralBalances[msg.sender] = 0;
        requested[msg.sender] = false; //Loan is now DONE
        return true;
    }

    function withdraw(uint256 amount) public {
        payable(msg.sender).transfer(amount);
    }

    function penalty() public view override returns (bool, uint256) {
        (uint256 amount, uint256 time) = nextPayment();
        return (_hasPenalty || time < block.timestamp, _lateFee);
    }

    function nextPayment() public view override returns (uint256, uint256) {
        uint256 depositTime = depositTimes[msg.sender];
        require(depositTime != 0, "Collateral not deposited");
        uint256 dueTime = depositTime + 10 days; // @note - 10 days after deposit of collateral
        return (_amounts[_paymentCount], dueTime);
    }

    function pay(uint256 amount) public override returns (bool) {
        (uint256 _amount, uint256 _time) = nextPayment();
        if (_amount == amount && _time < block.timestamp) {
            _hasPenalty = true;
        }
        _paymentCount++;
        return true;
    }

    function requestSimpleLoan() internal returns (bool) {
        // deposit collateral
        //1. The collateral has to be > to the amount requested
        IERC20(token).approve(address(stormbitLending), collateralAmount); // approve stormbitLending to return the collateral
        IERC20(token).transferFrom(msg.sender, address(stormbitLending), collateralAmount);
        depositTimes[msg.sender] = block.timestamp;

        // request loan
        IStormBitLending.LoanRequestParams memory params = IStormBitLending.LoanRequestParams({
            amount: loanAmount,
            token: token,
            agreement: address(this), // @note - this contract is the strategy used
            agreementCalldata: agreementCalldata
        });
        require(loanAmount < collateralAmount, "Collateral amount has to be greater than loan amount");
        stormbitLending.requestLoan(params);

        collateralBalances[msg.sender] = collateralAmount; // @audit - check for reentrancy
        requested[msg.sender] == true; // @audit - check for reentrancy
    }

    receive() external payable {}
}
