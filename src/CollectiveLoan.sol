// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./interfaces/ICollectiveLoan.sol";

error NOT_POOL_MANAGERS();

abstract contract CollectiveLoan is ICollectiveLoan {
    event PoolManagerAdded(address _poolManager);

    string constant ZERO_ADDRESS_ERROR = "CollectiveLoan: zero address";

    address public token;
    address public poolLauncher;

    uint8 public maxLenders;
    uint8 public minLenders;
    uint8 public requestLoanFee;

    address[] public borrowers;

    mapping(address => bool) public arePoolManagers;

    constructor(address _token, address _poolLauncher, uint8 _maxLenders, address[] memory _poolManagers) {
        require(_token != address(0), ZERO_ADDRESS_ERROR);
        require(_poolLauncher != address(0), ZERO_ADDRESS_ERROR);
        require(_poolManagers.length < _maxLenders);
        token = _token;
        poolLauncher = _poolLauncher;
        maxLenders = _maxLenders;
        _addPoolManagers(_poolManagers);
    }

    function setupCollective(uint8 _maxLenders, uint8 _minLenders, uint8 _requestLoanFee)
        external
        override
        onlyManagers
    {
        maxLenders = _maxLenders;
        minLenders = _minLenders;
        requestLoanFee = _requestLoanFee;
    }

    function _addPoolManagers(address[] memory _poolManagers) internal {
        for (uint256 i = 1; i < _poolManagers.length; ++i) {
            require(_poolManagers[i - 1] != address(0), ZERO_ADDRESS_ERROR);
            arePoolManagers[_poolManagers[i]] = true;
            emit PoolManagerAdded(_poolManagers[i]);
        }
    }

    // Vote for yes/no on the list of borrowers
    function vote() external view returns (bool _result) {
        for (uint256 i = 1; i < borrowers.length; ++i) {}
    }

    modifier onlyManagers() {
        if (arePoolManagers[msg.sender] == false) {
            revert NOT_POOL_MANAGERS();
        }
        _;
    }
}
