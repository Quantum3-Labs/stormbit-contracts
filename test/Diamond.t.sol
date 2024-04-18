pragma solidity 0.8.20;

import {Setup, BaseVault, console} from "./Setup.sol";
import {IAdmin} from "../src/interfaces/IAdmin.sol";
import {ICore, PoolInitData} from "../src/interfaces/ICore.sol";
import {ILending} from "../src/interfaces/ILending.sol";
import {IRegistry} from "../src/interfaces/IRegistry.sol";
import {Errors} from "../src/libraries/Common.sol";
import {MockToken} from "../src/mocks/MockToken.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DiamondTest is Setup {
    address owner1 = makeAddr("Creator1");
    address staker1 = makeAddr("Staker1");

    function setUp() public override {
        super.setUp();

        // register users
        vm.prank(staker1);
        IRegistry(address(stormbit)).register("staker1");
        vm.prank(owner1);
        IRegistry(address(stormbit)).register("owner1");

        // deal tokens and deposit
        _dealTokens(owner1, usdt, 100 * DECIMALS);
        _dealTokens(staker1, usdt, 100 * DECIMALS);
    }

    function test_AdminFacet() public {
        IAdmin admin = IAdmin(address(stormbit));
        require(admin.governor() == governor, "governor should be equal to the setup governor");
        vm.expectRevert(Errors.CallerIsNotGovernor.selector);
        admin.setNewGovernor(address(0));

        vm.prank(governor);
        admin.setNewGovernor(address(this));
        require(admin.governor() == address(this), "governor should be equal to the new governor");
    }

    function test_simpleDepositWithdraw() public {
        // create a pool
        ICore core = ICore(address(stormbit));
        vm.startPrank(owner1);
        usdt.approve(address(core), 100 * DECIMALS);
        uint256 poolId = core.createPool(
            PoolInitData({
                name: "Test Pool 1",
                creditScore: 0,
                maxAmountOfStakers: 10,
                votingQuorum: 5,
                maxPoolUsage: 100,
                votingPowerCoolDown: 10,
                assets: 100 * DECIMALS,
                asset: address(usdt),
                assetVault: address(usdtVault)
            })
        );
        vm.stopPrank();
        // deposit into the pool
        ILending lending = ILending(address(stormbit));
        vm.startPrank(staker1);
        usdt.approve(address(lending), 100 * DECIMALS);
        lending.deposit(poolId, 100 * DECIMALS);
        vm.stopPrank();

        // check balance of stormbit
        require(
            usdtVault.balanceOf(address(stormbit)) == 200 * DECIMALS * 10 ** _decimalsOffset(usdtVault),
            "stormbit should have 100 USDT"
        );

        require(poolId == 1, "poolId should be 1");

        uint256 totalSharesOfPool = lending.getTotalShares(poolId);

        // perform a withdraw
        vm.prank(staker1);
        vm.expectRevert();
        lending.withdraw(poolId, (totalSharesOfPool * 2) / 3);

        vm.prank(staker1);
        lending.withdraw(poolId, totalSharesOfPool / 4);

        vm.prank(owner1);
        lending.withdraw(poolId, totalSharesOfPool / 4);

        require(
            usdtVault.balanceOf(address(stormbit)) >= 99 * DECIMALS * 10 ** _decimalsOffset(usdtVault)
                && usdtVault.balanceOf(address(stormbit)) <= 101 * DECIMALS * 10 ** _decimalsOffset(usdtVault),
            "stormbit should have 100 USDT"
        );
    }

    function _dealTokensAndDeposit(address _user, MockToken _mockToken, uint256 amount) internal {
        vm.startPrank(_user);
        _mockToken.mint(_user, amount);
        usdt.approve(address(usdtVault), amount);
        usdtVault.deposit(amount, _user);
        vm.stopPrank();
    }

    function _dealTokens(address _user, MockToken _mockToken, uint256 amount) internal {
        vm.startPrank(_user);
        _mockToken.mint(_user, amount);
        vm.stopPrank();
    }

    // the vault decimals offset
    function _decimalsOffset(BaseVault vault) internal view returns (uint8) {
        return vault.decimals() - ERC20(vault.asset()).decimals();
    }
}
