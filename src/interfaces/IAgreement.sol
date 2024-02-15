pragma solidity ^0.8.21;

interface IAgreement {
    function paymentToken() external view returns (address);

    function lateFee() external view returns (uint256);

    function nextPayment() external view returns (uint256, uint256);

    function beforeLoan(bytes memory data) external returns (bool);

    function afterLoan(bytes memory data) external returns (bool);

    function withdraw() external;

    function getPaymentDates()
        external
        view
        returns (uint256[] memory, uint256[] memory);

    function payBack() external returns (bool);

    function initialize(bytes memory initData) external;

    function penalty() external returns (uint256);
}
