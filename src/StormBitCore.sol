// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.21;

// import "./StormBitLending.sol";
// import "./interfaces/IStormBit.sol";
// import "./interfaces/IStaking.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Pausable.sol";

// // - StormBit Core: main contract, a contract factory as well, is ownable and pausable. ( DAO governance for v2 )
// // used when creating pools
// // holds some shares of tokens on the ERC4626s which holds the revenue of the protocol.

// // Should receive NFT (ERC721) => Implements ERC721Receiver

// abstract contract StormBitCore is IStormBit, Ownable, Pausable {
//     event StormBitLendingPool(
//         address indexed token,
//         address indexed pool,
//         uint8 maxAmountOfStakers
//     );

//     address public staking;
//     uint256 public counter;

//     address public lastPool;
//     mapping(address => uint256) public poolCounters;

//     constructor(address _staking, address initialOwner) Ownable(initialOwner) {
//         staking = _staking;
//     }

//     function createPool(
//         address token,
//         uint8 _maxAmountOfStakers
//     ) public returns (address) {
//         bool haveStaked = IStaking(staking).haveAvailableStake(msg.sender);
//         require(haveStaked == true, "Need to ERC20 stake first");

//         StormBitLending stormBitLending = new StormBitLending(
//             token,
//             _maxAmountOfStakers,
//             msg.sender
//         );

//         counter++;
//         poolCounters[address(stormBitLending)] = counter;
//         lastPool = address(stormBitLending);
//         emit StormBitLendingPool(token, lastPool, _maxAmountOfStakers);
//         return lastPool;
//     }
// }
