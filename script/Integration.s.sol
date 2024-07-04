// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {MockToken} from "src/mocks/MockToken.sol";
import {AssetManager} from "../src/AssetManager.sol";
import {LendingManager} from "../src/LendingManager.sol";
import {LoanManager} from "../src/LoanManager.sol";
import {StormbitRegistry} from "src/StormbitRegistry.sol";
import {DeployHelpers, console} from "script/DeployHelpers.s.sol";
import {IHooks} from "src/interfaces/hooks/IHooks.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Integration is DeployHelpers {
    uint256 INITIAL_DEPOSIT = 1000 * 1e18;

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint256 borrowerPk = vm.envUint("BORROWER_PRIVATE_KEY");
        vm.startBroadcast(pk);
        LendingManager lendingManager = LendingManager(getDeployment("LendingManager"));
        StormbitRegistry registry = StormbitRegistry(getDeployment("StormbitRegistry"));
        AssetManager assetManager = AssetManager(getDeployment("AssetManager"));

        MockToken mockUsdt = MockToken(getDeployment("MockUsdt"));
        mockUsdt.mint(vm.addr(pk), INITIAL_DEPOSIT);

        // rebister and create a lending term
        registry.register("0xquantum3labs");
        uint256 term = lendingManager.createLendingTerm(1000, IHooks(address(0)));
        // depoist and delegate to term

        mockUsdt.approve(address(assetManager), 1000 * 1e18);
        assetManager.deposit(address(mockUsdt), 1000 * 1e18);

        address usdtVaultAddr = assetManager.getVaultToken(address(mockUsdt));
        IERC4626 usdtVault = IERC4626(usdtVaultAddr);

        uint256 sharesOfUser = usdtVault.balanceOf(vm.addr(pk));

        uint256 usdtVaultAmountWithDecimals = sharesOfUser / 2;
        usdtVault.approve(address(lendingManager), usdtVaultAmountWithDecimals);
        lendingManager.depositToTerm(term, address(mockUsdt), usdtVaultAmountWithDecimals);

        console.log("total shares");
        console.log(usdtVault.totalSupply());
        console.log("shares to deposit");
        console.log(usdtVaultAmountWithDecimals);

        // request loan
        vm.stopBroadcast();
        vm.startBroadcast(borrowerPk);
        LoanManager loanManager = LoanManager(getDeployment("LoanManager"));
        uint256 loanId =
            loanManager.requestLoan(getDeployment("MockUsdt"), INITIAL_DEPOSIT / 10, block.timestamp + 1 days);
        vm.stopBroadcast();

        // allocate to loan
        vm.startBroadcast(pk);
        loanManager.allocate(loanId, term, INITIAL_DEPOSIT / 10);
        vm.stopBroadcast();

        // execute the loan
        vm.startBroadcast(borrowerPk);
        loanManager.executeLoan(loanId);
        vm.stopBroadcast();
    }
}
