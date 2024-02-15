pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {StormBitLending, IStormBitLending} from "../src/StormBitLending.sol";
import {SimpleAgreement} from "../src/agreements/SimpleAgreement.sol";
import {MockToken} from "src/mocks/MockToken.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IAgreement} from "../src/interfaces/IAgreement.sol";
import {Vm} from "forge-std/Vm.sol";

contract StormbitLendingTest is Test {
    uint256 constant ONE_THOUSAND = 1000 * 10 ** 18;
    uint256 constant VOTING_POWER_COOLDOWN = 1 days;
    address public stormbitLendingImplementation;
    address public simpleAgreementImplementation;
    StormBitLending public stormbitLending;
    MockToken public mockToken;

    // sample test accounts
    address public staker1 = makeAddr("staker1");
    address public staker2 = makeAddr("staker2");
    address public staker3 = makeAddr("staker3");
    address public borrower1 = makeAddr("borrower1");

    function setUp() public {
        // create mock token
        mockToken = new MockToken();

        // mint tokens to every one
        mockToken.mint(staker1, 1000 * ONE_THOUSAND);
        mockToken.mint(staker2, 1000 * ONE_THOUSAND);
        mockToken.mint(staker3, 1000 * ONE_THOUSAND);
        mockToken.mint(borrower1, 1000 * ONE_THOUSAND);

        // create a new pool
        stormbitLendingImplementation = address(new StormBitLending());
        stormbitLending = StormBitLending(
            payable(Clones.clone(stormbitLendingImplementation))
        );

        // agreement implementations
        simpleAgreementImplementation = address(new SimpleAgreement());
    }

    function _initializeLendingPool() internal {
        address[] memory supportedAgreements = new address[](1);
        supportedAgreements[0] = simpleAgreementImplementation;

        address[] memory supportedAssets = new address[](1);
        supportedAssets[0] = address(mockToken);
        IStormBitLending.InitParams memory initParams = IStormBitLending
            .InitParams({
                name: "StormBit Lending",
                creditScore: 0,
                maxAmountOfStakers: 10,
                votingQuorum: 50,
                maxPoolUsage: 100,
                votingPowerCoolDown: VOTING_POWER_COOLDOWN,
                initAmount: 5 * ONE_THOUSAND,
                initToken: address(mockToken),
                supportedAssets: supportedAssets,
                supportedAgreements: supportedAgreements
            });

        vm.prank(staker1);
        mockToken.approve(address(stormbitLending), 5 * ONE_THOUSAND);
        stormbitLending.initializeLending(initParams, staker1);
    }

    function testInitialize() public {
        _initializeLendingPool();

        require(
            stormbitLending.isSupportedAgreement(simpleAgreementImplementation)
        );

        require(stormbitLending.balanceOf(staker1) == 5 * ONE_THOUSAND);
        require(stormbitLending.getValidVotes(staker1) == 0);
        skip(VOTING_POWER_COOLDOWN + 1);
        require(stormbitLending.getValidVotes(staker1) > 0);
    }

    // TODO : modify this dummy test
    function testRequestSimpleLoanE2EMinimalChecks() public {
        _initializeLendingPool();
        skip(VOTING_POWER_COOLDOWN + 1); // IMPORTANT: skip voting power cooldown

        uint256 today = block.timestamp;
        uint256 firstEndOfMonth = today + 30 days;
        uint256 secondEndOfMonth = firstEndOfMonth + 30 days;
        uint256 amountFirst = ONE_THOUSAND / 2;
        uint256 amountSecond = ONE_THOUSAND / 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountFirst;
        amounts[1] = amountSecond;

        uint256[] memory times = new uint256[](2);
        times[0] = firstEndOfMonth;
        times[1] = secondEndOfMonth;

        // build request loan params
        IStormBitLending.LoanRequestParams
            memory loanRequestParams = IStormBitLending.LoanRequestParams({
                amount: 1 * ONE_THOUSAND,
                token: address(mockToken),
                agreement: simpleAgreementImplementation,
                agreementCalldata: abi.encode(
                    1000,
                    borrower1,
                    address(mockToken),
                    amounts,
                    times
                )
            });

        vm.prank(borrower1);
        // get the events
        vm.recordLogs();
        uint256 proposalId = stormbitLending.requestLoan(loanRequestParams);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;
        bytes32 descriptionHash;
        {
            // check the event data is correct
            (
                uint256 _proposalId,
                address _proposer,
                address[] memory _targets,
                uint256[] memory _values,
                string[] memory _signatures, // doesnt matter to me
                bytes[] memory _calldatas,
                uint256 _voteStart, // doenst matter to me
                uint256 _voteEnd, // doesnt matter to me
                string memory _description
            ) = abi.decode(
                    logs[0].data,
                    (
                        uint256,
                        address,
                        address[],
                        uint256[],
                        string[],
                        bytes[],
                        uint256,
                        uint256,
                        string
                    )
                );

            // dont check signatures
            require(logs.length == 1);
            require(_proposalId == proposalId);
            require(_proposer == borrower1);
            require(_targets.length == 1);
            require(_targets[0] == address(stormbitLending));
            require(_values.length == 1);
            require(_values[0] == 0);
            require(_calldatas.length == 1);

            targets = _targets;
            values = _values;
            calldatas = _calldatas;
            descriptionHash = keccak256(bytes(_description));
        }
        // check proposer
        require(stormbitLending.proposalProposer(proposalId) == borrower1);

        // voting delay is zero we can start voting right away
        skip(1);

        IGovernor.ProposalState proposalState = stormbitLending.state(
            proposalId
        );

        require(proposalState == IGovernor.ProposalState.Active);

        // vote for the proposal
        vm.prank(staker1);
        stormbitLending.castVote(proposalId, 1); // vote yes

        // execute the proposal
        uint256 votingPeriod = stormbitLending.votingPeriod();
        skip(votingPeriod);

        (uint256 againstVotes, uint256 forVotes, ) = stormbitLending
            .proposalVotes(proposalId);
        require(forVotes > againstVotes);
        require(forVotes == stormbitLending.balanceOf(staker1));
        proposalState = stormbitLending.state(proposalId);

        // proposal has been successfull
        require(proposalState == IGovernor.ProposalState.Succeeded);

        // assume stormbit core is this contract
        vm.prank(address(this));
        stormbitLending.execute(targets, values, calldatas, descriptionHash);

        // get the user agreement
        address userAgreement = stormbitLending.userAgreement(borrower1);
        require(userAgreement != address(0));

        // user withdraws money
        uint256 balanceBefore = mockToken.balanceOf(borrower1);
        vm.prank(borrower1);
        IAgreement(userAgreement).withdraw();
        uint256 balanceAfter = mockToken.balanceOf(borrower1);
        require(balanceAfter - balanceBefore == 1 * ONE_THOUSAND); // user has withdrawn the money he requested
    }

    function testSimpleAgreement() public {
        // SimpleAgreement agreement = new SimpleAgreement();
        // agreement.loan(100, 100, 100,
    }

    // util function to be able to test
    function isKYCVerified(address _address) public pure returns (bool) {
        return true;
    }
}
