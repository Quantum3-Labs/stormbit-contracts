pragma solidity ^0.8.21;

import "../StrategyBase.sol";
import "../StormBitCore.sol";
import "../StormBitLending.sol";

contract BaseAgreement is StrategyBase {
    StormBitCore stormbitCore;
    StormBitLending stormbitLending;

    constructor(StormBitCore _stormbitCore, StormBitLending _stormbitLending) public {
        stormbitCore = _stormbitCore;
        stormbitLending = _stormbitLending;
    }

    function beforeLoan(bytes memory) external override returns (bool) {
        require(stormbitCore.isKYCVerified(msg.sender));
    }

    function afterLoan(bytes memory) external override returns (bool) {
        return true;
    }

    function penalty() public view override returns (bool, uint256) {
        (uint256 amount, uint256 time) = nextPayment();
        return (_hasPenalty || time < block.timestamp, _lateFee);
    }

    function pay(uint256 amount) public override returns (bool) {
        (uint256 _amount, uint256 _time) = nextPayment();
        if (_amount == amount && _time < block.timestamp) {
            _hasPenalty = true;
        }
        _paymentCount++;
        return true;
    }

    function requestSimpleLoan(uint256 loanAmount, address token, bytes calldata strategyCalldata) public {
         // request loan
        IStormBitLending.LoanRequestParams memory params = IStormBitLending.LoanRequestParams({
            amount: loanAmount,
            token: token,
            strategy: address(this), // @note - this contract is the strategy used
            strategyCalldata: strategyCalldata
        });
        stormbitLending.requestLoan(params);
    }
}
