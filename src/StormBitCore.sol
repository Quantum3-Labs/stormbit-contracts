// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "./interfaces/IStormBitLending.sol";
import "./interfaces/IStormBit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// - StormBit Core: main contract, a contract factory as well, is ownable and pausable. ( DAO governance for v2 )
// used when creating pools
// holds some shares of tokens on the ERC4626s which holds the revenue of the protocol.

// Should receive NFT (ERC721) => Implements ERC721Receiver

contract StormBitCore is IStormBit, Ownable, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;
    address public lastPool;
    EnumerableSet.AddressSet internal _lendingPools;
    address internal _lendingPoolImplementation;

    modifier onlyKYCVerified() {
        require(isKYCVerified(msg.sender), "StormBit: KYC not verified");
        _;
    }

    constructor(
        address initialOwner,
        address lendingPoolImplementation
    ) Ownable(initialOwner) {
        _lendingPoolImplementation = lendingPoolImplementation;
    }

    function createPool(
        IStormBitLending.InitParams memory params
    ) external onlyKYCVerified {
        address newPool = Clones.clone(_lendingPoolImplementation);
        // transfer the tokens
        IERC20(params.initToken).transferFrom(
            msg.sender,
            newPool,
            params.initAmount
        );
        IStormBitLending(newPool).initialize(params, msg.sender);

        emit PoolCreated(newPool, msg.sender);
    }

    function _validate(IStormBitLending.InitParams memory params) internal {
        // TODO : perform some checks on the params, protocol checkks
        // require some checks
    }

    function isKYCVerified(address _address) public view returns (bool) {
        return true;
    }

    function isSupportedStrategy(address _strategy) public view returns (bool) {
        return true;
    }
}
