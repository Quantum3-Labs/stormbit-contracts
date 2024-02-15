pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IAgreement.sol";

abstract contract AgreementBedrock is IAgreement, Initializable {
    // first elements in storage use Storage s lot in the future. for better security
    // basic agreement components
    uint256 internal _lateFee;
    address internal _paymentToken;
    address internal _lender;
    address internal _borrower;
    bool internal _hasPenalty;
    uint256[] internal _amounts;
    uint256[] internal _times;

    uint256 internal _paymentCount = 0;

    modifier onlyBorrower() {
        require(msg.sender == _borrower, "AgreementBedrock: not borrower");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        bytes memory initData
    ) public virtual override initializer {
        (
            uint256 lateFee,
            address borrower,
            address PaymentToken,
            uint256[] memory amounts,
            uint256[] memory times
        ) = abi.decode(
                initData,
                (uint256, address, address, uint256[], uint256[])
            );
        _lateFee = lateFee;
        _lender = msg.sender; // lender deploys this, aka lending pool
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

    function lender() public view virtual override returns (address) {
        return _lender;
    }

    function borrower() public view virtual override returns (address) {
        return _borrower;
    }

    function nextPayment()
        public
        view
        virtual
        override
        returns (uint256, uint256)
    {
        return (_amounts[_paymentCount], _times[_paymentCount]);
    }

    function getPaymentDates()
        public
        view
        virtual
        override
        returns (uint256[] memory, uint256[] memory)
    {
        return (_amounts, _times);
    }

    function totalLoanAmount() public view virtual override returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            total += _amounts[i];
        }
        return total;
    }

    function isLoanFinished() public view virtual override returns (bool) {
        return _paymentCount == _amounts.length;
    }

    function payBack() public override returns (bool) {
        (uint256 amount, ) = nextPayment();
        uint256 fee = penalty();
        IERC20(_paymentToken).transfer(address(this), amount + fee);
        _paymentCount++;
        if (isLoanFinished()) {
            _afterLoan();
        }
        return true;
    }

    function penalty() public view override returns (uint256) {
        (uint256 amount, uint256 time) = nextPayment();
        if (_hasPenalty || time < block.timestamp) {
            return (_lateFee);
        }
        return 0;
    }

    function withdraw() external virtual override onlyBorrower {
        _beforeLoan();
        IERC20(_paymentToken).transfer(
            _borrower,
            IERC20(_paymentToken).balanceOf(address(this))
        );
    }

    // -------------------- CUSTOM FUNCTIONS --------------------

    function _beforeLoan() internal virtual;

    function _afterLoan() internal virtual;
}
