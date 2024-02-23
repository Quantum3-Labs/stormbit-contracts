// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

// import "./interfaces/IStormBitLending.sol";
import {IStormBit, IStormBitLending} from "./interfaces/IStormBit.sol";
import {IAgreement} from "./interfaces/IAgreement.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IStormBitLendingVotes} from "./interfaces/IStormBitLendingVotes.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {
    GovernorVotesUpgradeable,
    IVotes
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {GovernorVotesQuorumFractionUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";

import {GovernorCountingSimpleUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// - StormBitLending: implementation contract to be used when creating new lending pools.
//     - has a bunch of setters and getters that are only owner.
//     - has a approve loan function that is only available for people with voting power. ( can use a tweaked governance here )

contract StormBitLending is
    IStormBitLending,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuard,
    GovernorUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable
{
    // ---------- CONFIG VARS ----------
    string _poolName;
    uint256 _creditScore;
    uint256 _maxAmountOfStakers;
    uint256 _votingQuorum;
    uint256 _maxPoolUsage;
    uint256 _votingPowerCoolDown;
    uint256 _loanRequestNonce = 0;
    address internal _lendingVotes;

    IStormBit internal _stormBit;
    mapping(address => bool) public _isSupportedAsset;
    mapping(bytes4 => bool) public _isSupportedAction;
    mapping(address => bool) public _isSupportedAgreement;

    mapping(address => address) public _userAgreement;
    mapping(uint256 => LoanDetails) public _loanDetails;

    // ------------ TODO : dummy helpers in frontend remove ---------
    uint256 _totalBorrowed;
    uint256 _totalSupplied;
    address[] public _supportedAssets;
    address[] public _supportedAgreements;
    address[] public _stakers;
    uint256[] public _loanRequests;

    constructor() {
        _disableInitializers();
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "StormBitLending: not self");
        _;
    }

    modifier onlyStormBit() {
        require(msg.sender == address(_stormBit), "StormBitLending: not StormBit");
        _;
    }

    modifier onlyKYCVerified() {
        require(_stormBit.isKYCVerified(msg.sender), "StormBitLending: KYC not verified");
        _;
    }

    function initializeLending(InitParams memory params, address _firstOwner, address stormBitLendingVotes)
        external
        override
        initializer
    {
        _poolName = params.name;
        _stormBit = IStormBit(msg.sender);
        _creditScore = params.creditScore;
        _maxAmountOfStakers = params.maxAmountOfStakers;
        _votingQuorum = params.votingQuorum;
        _maxPoolUsage = params.maxPoolUsage;
        _votingPowerCoolDown = params.votingPowerCoolDown;
        _lendingVotes = stormBitLendingVotes;

        __Ownable_init(_firstOwner);
        __Governor_init(_poolName);
        __GovernorVotes_init(IVotes(stormBitLendingVotes));
        __GovernorVotesQuorumFraction_init(_votingQuorum);

        (address initToken, uint256 initAmount, address[] memory supportedAssets) =
            (params.initToken, params.initAmount, params.supportedAssets);

        // setup supported calls
        _isSupportedAction[this.changeVotingQuorum.selector] = true;
        _isSupportedAction[this.changeMaxPoolUsage.selector] = true;
        _isSupportedAction[this.changeVotingPowerCoolDown.selector] = true;
        _isSupportedAction[this.changeMaxAmountOfStakers.selector] = true;

        // setup supported assets
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            _isSupportedAsset[supportedAssets[i]] = true;
            _supportedAssets.push(supportedAssets[i]);
        }

        // check if init token is supported
        require(_isSupportedAsset[initToken], "StormBitLending: init token not supported");
        for (uint256 i = 0; i < params.supportedAgreements.length; i++) {
            _isSupportedAgreement[params.supportedAgreements[i]] = true;
            _supportedAgreements.push(params.supportedAgreements[i]);
        }
        // check if this pool already has the amount of assets of the token in the ERC4626 of the main contract
        // setup with first deposit @notice Transfer is done from core.
        // IERC20(initToken).transferFrom(_firstOwner, address(this), initAmount);
        _stake(initAmount, _firstOwner);
    }

    function stake(address token, uint256 amount) external onlyKYCVerified {
        // transfer the assets from the user into the ERC4626 of the main contract
        // stake the amount of shares in the pool
        require(_isSupportedAsset[token], "StormBitLending: asset not supported");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        _stake(amount, msg.sender);
    }

    function requestLoan(LoanRequestParams memory params)
        external
        virtual
        onlyKYCVerified
        returns (uint256 proposalId)
    {
        // TODO perform checks on the amounts that are requested on the agreement contract
        require(_isSupportedAgreement[params.agreement], "StormBitLending: agreement not supported");
        require(_isSupportedAsset[params.token], "StormBitLending: asset not supported");
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = string(abi.encode("Request Loan at ", _loanRequestNonce));
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            this.executeLoan.selector,
            params.token,
            msg.sender,
            params.amount,
            params.agreement,
            params.agreementCalldata
        );
        _loanRequestNonce++;
        uint256 loanRequestId = _propose(targets, values, calldatas, description, msg.sender);
        _loanRequests.push(loanRequestId);
        _loanDetails[loanRequestId] = LoanDetails({
            token: params.token,
            amount: params.amount,
            agreement: params.agreement,
            agreementCalldata: params.agreementCalldata,
            loanId: loanRequestId,
            borrower: msg.sender
        });
        return loanRequestId;
    }

    // ---------- STORMBIT CALLS ----------------
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override(GovernorUpgradeable) onlyStormBit returns (uint256) {
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    // ---------- SELF CALLABLE - GOV FUNCTIONS ----------------

    function executeLoan(address token, address to, uint256 amount, address agreement, bytes calldata agreementCalldata)
        external
        onlySelf
    {
        require(_userAgreement[to] == address(0), "StormBitLending: user has loan");
        address newAgreement = Clones.clone(agreement);
        IAgreement(newAgreement).initialize(agreementCalldata);
        IERC20(token).transfer(newAgreement, amount);
        _userAgreement[to] = newAgreement;

        _totalBorrowed += amount;
    }

    function changeAgreementStatus(address agreement, bool status) external onlySelf {
        _changeAgreementStatus(agreement, status);
    }

    function changeVotingQuorum(uint256 newQuorum) external onlySelf {
        _votingQuorum = newQuorum;
    }

    function changeMaxPoolUsage(uint256 newMaxPoolUsage) external onlySelf {
        _maxPoolUsage = newMaxPoolUsage;
    }

    function changeVotingPowerCoolDown(uint256 newCoolDown) external onlySelf {
        _votingPowerCoolDown = newCoolDown;
    }

    function changeMaxAmountOfStakers(uint256 newMaxAmountOfStakers) external onlySelf {
        _maxAmountOfStakers = newMaxAmountOfStakers;
    }

    // ---------- INTERNALS ----------------

    function _changeAgreementStatus(address agreement, bool status) internal {
        _isSupportedAgreement[agreement] = status;
    }

    function _stake(uint256 amount, address staker) internal {
        // calculate the shares of the pool that belong to this amount
        // we can consider all tokens to have same weight first

        // TODO : change this
        uint256 sharesInPool = amount;
        IStormBitLendingVotes(_lendingVotes).mint(staker, sharesInPool);
        IStormBitLendingVotes(_lendingVotes).delegate(staker, staker); // self delegate

        _totalSupplied += amount;
        _stakers.push(staker);
    }

    // ---------- OVERRIDES ---------------------------
    function votingDelay() public pure override returns (uint256) {
        return 0;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 7 days; // 1 week
    }

    function name() public view override(GovernorUpgradeable) returns (string memory) {
        return _poolName;
    }

    function creditScore() public view returns (uint256) {
        return _creditScore;
    }

    function clock() public view override(GovernorUpgradeable, GovernorVotesUpgradeable) returns (uint48) {
        return SafeCast.toUint48(block.timestamp);
    }

    // to get the erc20 votes power now , calls this
    /**
     * function getPastVotes(address account, uint256 timepoint) where timepoint is block timestamp - cool down
     */

    function getValidVotes(address account) public view returns (uint256) {
        if (block.timestamp < _votingPowerCoolDown) return 0;
        return IVotes(_lendingVotes).getPastVotes(account, block.timestamp - _votingPowerCoolDown);
    }

    function getPoolData() public view returns (PoolData memory) {
        return PoolData({
            name: _poolName,
            creditScore: _creditScore,
            maxAmountOfStakers: _maxAmountOfStakers,
            votingQuorum: _votingQuorum,
            maxPoolUsage: _maxPoolUsage,
            totalBorrowed: _totalBorrowed,
            totalSupplied: _totalSupplied,
            stakers: _stakers,
            supportedAssets: _supportedAssets,
            supportedAgreements: _supportedAgreements,
            loanRequests: _loanRequests
        });
    }

    function getLoanData(uint256 loanRequestId) public view returns (LoanDetails memory, ProposalState, address) {
        // State. 0 - pending, 1 - active, 2 - canceled, 3 - defeated, 4 - succeeded
        return (_loanDetails[loanRequestId], state(loanRequestId), _userAgreement[_loanDetails[loanRequestId].borrower]);
    }

    // in percentage
    function getVotingPower(address staker) public view returns (uint256) {
        uint256 tokenSupply = IERC20(_lendingVotes).totalSupply();
        uint256 stakerValidVotes = getValidVotes(staker);
        return (stakerValidVotes * 100) / tokenSupply;
    }

    function isSupportedAgreement(address agreement) public view returns (bool) {
        return _isSupportedAgreement[agreement];
    }

    function userAgreement(address user) public view returns (address) {
        return _userAgreement[user];
    }

    function _getVotes(address account, uint256 timepoint, bytes memory /*params*/ )
        internal
        view
        override(GovernorUpgradeable, GovernorVotesUpgradeable)
        returns (uint256)
    {
        if (timepoint < _votingPowerCoolDown) return 0;
        return super._getVotes(account, timepoint - _votingPowerCoolDown, "");
    }

    function CLOCK_MODE()
        public
        view
        virtual
        override(GovernorUpgradeable, GovernorVotesUpgradeable)
        returns (string memory)
    {
        return "mode=blocktimestamp&from=default";
    }
}
