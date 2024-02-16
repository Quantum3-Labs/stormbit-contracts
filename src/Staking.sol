// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.21;

// import "./interfaces/IStaking.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract Staking is IStaking, Ownable {
//     using SafeERC20 for IERC20;

//     enum Aggreement {
//         BaseAgreement,
//         NFTAgreement,
//         FTAgreement
//     }

//     uint256 public minimumStake;
//     uint256 public lockPeriod;
//     address public token;
//     address[] public borrowers;

//     mapping(address => LendingPool.Lender) public loans;
//     mapping(address => bool) public haveStaked;
//     mapping(uint256 => uint256) public totalSupplied; // mapping of poolId to totalSupplied

//     event stakedInPool(address indexed staker, uint256 tokens);

//     constructor(
//         address _token,
//         uint256 _minimumStake,
//         uint256 _lockPeriod
//     ) Ownable(msg.sender) {
//         token = token;
//         minimumStake = _minimumStake;
//         lockPeriod = _lockPeriod;
//     }

//     function setMinimumStake(
//         uint256 _minimumStake
//     ) external override onlyOwner {
//         minimumStake = _minimumStake;
//     }

//     /**
//      * @dev stake tokens on the pool
//      */
//     function stake(uint256 _tokens) external override {
//         require(_tokens > 0, "Staking: zero tokens");
//         require(
//             _tokens >= minimumStake,
//             "Staking: tokens less than minimum stake"
//         );

//         // stake is added to the total supply
//         totalSupplied += _tokens;
//         // safeTransferFrom(msg.sender, address(this), _tokens);
//         emit stakedInPool(msg.sender, _tokens);
//     }

//     /**
//      * @dev reetire staked tokens from the pool, and lock them
//      */
//     function unstake(uint256 _tokens) external override {}

//     function withdraw(address _lender) external override {
//         require(LendingPool.poolWithdraw() > 0);
//     }

//     function haveAvailableStake(
//         address _staker
//     ) external view override returns (bool) {
//         haveStaked[_staker] = true;
//     }
// }
