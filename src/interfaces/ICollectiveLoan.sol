// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface ICollectiveLoan {
    enum CollectiveLoanStatus {
        Launched,
        Open,
        Complete
    }

    function status() external view returns (CollectiveLoanStatus);

    function addPoolManagers(address[] memory _poolManagers) external;

    function setupCollective(uint8 _maxLenders, uint8 _minLenders, uint8 _requestLoanFee) external;

    function requestLoan() external;

    function vote() external view returns (bool _result);

    function abort() external;

    function cancel() external returns (bool);
}
