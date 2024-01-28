// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IStormBitLending {
    enum StormBitLendingStatus {
        Launched,
        Open,
        Complete
    }

    function status() external view returns (StormBitLendingStatus);

    function addPoolManagers(address[] memory _poolManagers) external;

    function setupPool(uint8 _maxLenders, uint8 _requestLoanFee) external;

    function requestLoan() external;

    function vote() external view returns (bool _result);

    function abort() external;

    function cancel() external returns (bool);
}
