// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "./interfaces/IStormBitLending.sol";
import "./interfaces/IStormBit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";

// - StormBitLending: implementation contract to be used when creating new lending pools.
//     - has a bunch of setters and getters that are only owner.
//     - has a approve loan function that is only available for people with voting power. ( can use a tweaked governance here )

contract StormBitLending is
    IStormBitLending,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuard,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    GovernorUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable
{
    // ---------- CONFIG VARS ----------
    uint256 _creditScore;
    uint256 _maxAmountOfStakers;
    uint256 _votingQuorum;
    uint256 _maxPoolUsage;
    uint256 _votingPowerCoolDown;
    uint256 _loanRequestNonce = 0;
    IStormBit internal _stormBit;
    mapping(address => bool) public _isSupportedAsset;
    mapping(bytes4 => bool) public _isSupportedAction;
    mapping(address => bool) public _isSupportedStrategy;

    constructor() {
        _disableInitializers();
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "StormBitLending: not self");
        _;
    }

    modifier onlyKYCVerified() {
        require(
            _stormBit.isKYCVerified(msg.sender),
            "StormBitLending: KYC not verified"
        );
        _;
    }

    function initialize(
        InitParams memory params,
        address _firstOwner
    ) external override initializer {
        _stormBit = IStormBit(msg.sender);
        _creditScore = params.creditScore;
        _maxAmountOfStakers = params.maxAmountOfStakers;
        _votingQuorum = params.votingQuorum;
        _maxPoolUsage = params.maxPoolUsage;
        _votingPowerCoolDown = params.votingPowerCoolDown;

        __Ownable_init(_firstOwner);
        __ERC20_init("StormBitLending", "SBL");
        __ERC20Permit_init("StormBitLending");
        __Governor_init("StormBitLending");
        __GovernorVotes_init(IVotes(address(this)));
        __GovernorVotesQuorumFraction_init(_votingQuorum);

        (
            address initToken,
            uint256 initAmount,
            address[] memory supportedAssets
        ) = (params.initToken, params.initAmount, params.supportedAssets);

        // setup supported calls
        _isSupportedAction[this.changeVotingQuorum.selector] = true;
        _isSupportedAction[this.changeMaxPoolUsage.selector] = true;
        _isSupportedAction[this.changeVotingPowerCoolDown.selector] = true;
        _isSupportedAction[this.changeMaxAmountOfStakers.selector] = true;

        // check if this pool already has the amount of assets of the token in the ERC4626 of the main contract

        // setup with first deposit
        _stake(initAmount, _firstOwner);
    }

    function stake(address token, uint256 amount) external onlyKYCVerified {
        // deposits the assets in the ERC4626 of the main contract

        // stake the amount of shares in the pool
        _stake(amount, msg.sender);
    }

    function _stake(uint256 amount, address staker) internal {
        // calculate the shares of the pool that belong to this amount
        // we can consider all tokens to have same weight first

        // TODO : change this
        uint256 sharesInPool = amount;
        _mint(staker, sharesInPool);
        _delegate(staker, staker); // self delegate
    }

    function requestLoan(
        LoanRequestParams memory params
    ) external onlyKYCVerified {
        // pre application checks
        require(
            _isSupportedStrategy[params.strategy],
            "StormBitLending: strategy not supported"
        );
        require(
            _isSupportedAsset[params.token],
            "StormBitLending: asset not supported"
        );
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = string(
            abi.encode("Request Loan at ", _loanRequestNonce)
        );
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            this.executeLoan.selector,
            params.token,
            msg.sender,
            params.amount,
            params.strategy,
            params.strategyCalldata
        );
        _loanRequestNonce++;
        _propose(targets, values, calldatas, description, msg.sender);
    }

    // ---------- SELF CALLABLE - GOV FUNCTIONS ----------------

    function executeLoan(
        address token,
        address to,
        uint256 amount,
        address strategy,
        bytes calldata strategyCalldata
    ) external onlySelf {
        // TODO : on the ERC4626 of the main contract, transfer the corresponding shares to the user.
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

    function changeMaxAmountOfStakers(
        uint256 newMaxAmountOfStakers
    ) external onlySelf {
        _maxAmountOfStakers = newMaxAmountOfStakers;
    }

    // ---------- OVERRIDES ---------------------------

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, value);
    }

    function nonces(
        address owner
    )
        public
        view
        override(NoncesUpgradeable, ERC20PermitUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function votingDelay() public pure override returns (uint256) {
        return 0;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 7 days; // 1 week
    }

    function name()
        public
        view
        override(GovernorUpgradeable, ERC20Upgradeable)
        returns (string memory)
    {
        return "StormBitLending";
    }

    function clock()
        public
        view
        override(
            GovernorUpgradeable,
            GovernorVotesUpgradeable,
            VotesUpgradeable
        )
        returns (uint48)
    {
        return SafeCast.toUint48(block.timestamp);
    }

    function CLOCK_MODE()
        public
        view
        virtual
        override(
            GovernorUpgradeable,
            GovernorVotesUpgradeable,
            VotesUpgradeable
        )
        returns (string memory)
    {
        return "mode=blocknumber&from=default";
    }

    function quorum(
        uint256 timepoint
    )
        public
        view
        override(GovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(timepoint - _votingPowerCoolDown);
    }
}
