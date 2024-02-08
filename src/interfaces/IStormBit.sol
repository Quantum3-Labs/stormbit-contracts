// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

interface IStormBit {
    enum StormBitStatus {
        Launched,
        Open,
        Complete
    }

    function status() external view returns (StormBitStatus);

    function addPoolManagers(address[] memory _poolManagers) external;

    function setupCollective(
        uint8 _maxLenders,
        uint8 _minLenders,
        uint8 _requestLoanFee
    ) external;

    function requestLoan() external;

    function vote() external view returns (bool _result);

    function abort() external;

    function cancel() external returns (bool);

    function isKYCVerified(address _address) external view returns (bool);
}
