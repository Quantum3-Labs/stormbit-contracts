pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IAgreement.sol";

abstract contract AgreementBedrock is IAgreement, Initializable {
    uint256 public _lateFee;
    address public _paymentToken;
    address public _deployer;
    address public _lender;
    address public _borrower;
    uint256 public _paymentCount;
    bool public _hasPenalty;

    uint256[] public _amounts;
    uint256[] public _times;

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes memory initData) external virtual override initializer {
        (
            uint256 lateFee,
            address lender,
            address borrower,
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
    }

    function lateFee() public view virtual override returns (uint256) {
        return _lateFee;
    }

    function paymentToken() public view virtual override returns (address) {
        return _paymentToken;
    }

    function nextPayment() public view virtual override returns (uint256, uint256) {
        return (_amounts[_paymentCount], _times[_paymentCount]);
    }

    function payBack() public virtual override returns (bool);

    function withdraw() external virtual override;

    function getPaymentDates() public view virtual override returns (uint256[] memory, uint256[] memory) {
        return (_amounts, _times);
    }

    function penalty() public view virtual override returns (uint256);
}
