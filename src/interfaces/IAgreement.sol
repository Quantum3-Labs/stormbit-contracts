pragma solidity ^0.8.21;

interface IAgreement {
    function paymentToken() external view returns (address);

    function lateFee() external view returns (uint256);

    function nextPayment() external view returns (uint256, uint256);

    function withdraw() external;

    function getPaymentDates() external view returns (uint256[] memory, uint256[] memory);

    function payBack() external returns (bool);

    function initialize(bytes memory initData) external;

    function penalty() external returns (uint256);

    function lender() external view returns (address); // lending pool

    function borrower() external view returns (address);

    function isLoanFinished() external view returns (bool);

    function totalLoanAmount() external view returns (uint256);
}
