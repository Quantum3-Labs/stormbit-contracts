// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {MockToken} from "src/mocks/MockToken.sol";
import {AssetManager} from "../src/AssetManager.sol";
import {LendingManager} from "../src/LendingManager.sol";
import {LoanManager} from "../src/LoanManager.sol";
import {StormbitRegistry} from "src/StormbitRegistry.sol";
import {DeployHelpers, console} from "script/DeployHelpers.s.sol";
import {IHooks} from "src/interfaces/hooks/IHooks.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Integration2 is DeployHelpers {
    uint256 INITIAL_DEPOSIT = 1000 * 1e18;
    uint256 LOAN_AMOUNT = 100 * 1e18;

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        LendingManager lendingManager = LendingManager(getDeployment("LendingManager"));
        StormbitRegistry registry = StormbitRegistry(getDeployment("StormbitRegistry"));
        AssetManager assetManager = AssetManager(getDeployment("AssetManager"));

        MockToken mockUsdt = MockToken(getDeployment("MockUsdt"));
        mockUsdt.mint(vm.addr(pk), INITIAL_DEPOSIT);

        // Register and create lending terms
        registry.register("mehdi");
        uint256 term1 = lendingManager.createLendingTerm(1, IHooks(address(0))); // 1% commission
        uint256 term2 = lendingManager.createLendingTerm(2, IHooks(address(0))); // 2% commission
        uint256 term3 = lendingManager.createLendingTerm(3, IHooks(address(0))); // 3% commission

        // Deposit and delegate to terms
        mockUsdt.approve(address(assetManager), INITIAL_DEPOSIT);
        assetManager.deposit(address(mockUsdt), INITIAL_DEPOSIT);

        address usdtVaultAddr = assetManager.getVaultToken(address(mockUsdt));
        IERC4626 usdtVault = IERC4626(usdtVaultAddr);

        uint256 sharesOfUser = usdtVault.balanceOf(vm.addr(pk));
        uint256 usdtVaultAmountWithDecimals = sharesOfUser / 3;

        usdtVault.approve(address(lendingManager), usdtVaultAmountWithDecimals);
        lendingManager.depositToTerm(term1, address(mockUsdt), usdtVaultAmountWithDecimals);

        usdtVault.approve(address(lendingManager), usdtVaultAmountWithDecimals);
        lendingManager.depositToTerm(term2, address(mockUsdt), usdtVaultAmountWithDecimals);

        usdtVault.approve(address(lendingManager), usdtVaultAmountWithDecimals);
        lendingManager.depositToTerm(term3, address(mockUsdt), usdtVaultAmountWithDecimals);

        console.log("total shares");
        console.log(usdtVault.totalSupply());
        console.log("shares to deposit");
        console.log(usdtVaultAmountWithDecimals);
        vm.stopBroadcast();

        // Borrowers requesting loans
        address[] memory borrowers = new address[](5);
        borrowers[0] = vm.addr(vm.envUint("BORROWER_PRIVATE_KEY_1"));
        borrowers[1] = vm.addr(vm.envUint("BORROWER_PRIVATE_KEY_2"));
        borrowers[2] = vm.addr(vm.envUint("BORROWER_PRIVATE_KEY_3"));
        borrowers[3] = vm.addr(vm.envUint("BORROWER_PRIVATE_KEY_4"));
        borrowers[4] = vm.addr(vm.envUint("BORROWER_PRIVATE_KEY_5"));

        LoanManager loanManager = LoanManager(getDeployment("LoanManager"));

        for (uint256 i = 0; i < borrowers.length; i++) {
            uint256 borrowerPk = vm.envUint(string(abi.encodePacked("BORROWER_PRIVATE_KEY_", i + 1)));
            vm.startBroadcast(borrowerPk);
            uint256 loanId = loanManager.requestLoan(address(mockUsdt), LOAN_AMOUNT, block.timestamp + 1 days);
            vm.stopBroadcast();

            // Allocate and execute loans
            vm.startBroadcast(pk);
            loanManager.allocate(loanId, (i % 3 == 0) ? term1 : (i % 3 == 1) ? term2 : term3, LOAN_AMOUNT);
            vm.stopBroadcast();

            vm.startBroadcast(borrowerPk);
            loanManager.executeLoan(loanId);
            vm.stopBroadcast();
        }

        // Adding lenders
        address[] memory lenders = new address[](4);
        lenders[0] = vm.addr(vm.envUint("LENDER_PRIVATE_KEY_1"));
        lenders[1] = vm.addr(vm.envUint("LENDER_PRIVATE_KEY_2"));
        lenders[2] = vm.addr(vm.envUint("LENDER_PRIVATE_KEY_3"));
        lenders[3] = vm.addr(vm.envUint("LENDER_PRIVATE_KEY_4"));

        // Each lender has a unique private key
        for (uint256 i = 0; i < lenders.length; i++) {
            uint256 lenderPk = vm.envUint(string(abi.encodePacked("LENDER_PRIVATE_KEY_", i + 1)));
            vm.startBroadcast(lenderPk);
            mockUsdt.mint(vm.addr(lenderPk), INITIAL_DEPOSIT);
            mockUsdt.approve(address(assetManager), INITIAL_DEPOSIT);
            assetManager.deposit(address(mockUsdt), INITIAL_DEPOSIT);
            usdtVault.approve(address(lendingManager), usdtVaultAmountWithDecimals);
            lendingManager.depositToTerm((i % 3 == 0) ? term1 : (i % 3 == 1) ? term2 : term3, address(mockUsdt), usdtVaultAmountWithDecimals);
            vm.stopBroadcast();
        }
    }
}
