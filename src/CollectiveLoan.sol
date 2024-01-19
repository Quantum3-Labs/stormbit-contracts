// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

contract CollectiveLoan {
    event PoolManagerAdded(address _poolManager);

    string constant ZERO_ADDRESS_ERROR = "CollectiveLoan: zero address";

    address public token;
    address public poolLauncher; 

    uint8 public maxLenders;

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

    function _addPoolManagers(address[] memory _poolManagers) internal {
        for (uint256 i = 1; i < _poolManagers.length; ++i) {
            require(_poolManagers[i - 1] != address(0), ZERO_ADDRESS_ERROR);
            arePoolManagers[_poolManagers[i]] = true;
            emit PoolManagerAdded(_poolManagers[i]);
        }
    }

}
