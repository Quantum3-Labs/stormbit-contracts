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
    uint256 LOAN_AMOUNT = 100 * 1e18;
    uint16 constant BASIS_POINTS = 10000;

    function run() public {
        uint256 lenderPk1 = vm.envUint("LENDER1_PRIVATE_KEY");
        uint256 lenderPk2 = vm.envUint("LENDER2_PRIVATE_KEY");
        uint256 borrowerPk1 = vm.envUint("BORROWER1_PRIVATE_KEY");
        uint256 borrowerPk2 = vm.envUint("BORROWER2_PRIVATE_KEY");

        vm.startBroadcast(lenderPk1);
        LendingManager lendingManager = LendingManager(getDeployment("LendingManager"));
        StormbitRegistry registry = StormbitRegistry(getDeployment("StormbitRegistry"));
        AssetManager assetManager = AssetManager(getDeployment("AssetManager"));
        MockToken mockUsdt = MockToken(getDeployment("MockUsdt"));
        mockUsdt.mint(vm.addr(lenderPk1), INITIAL_DEPOSIT);
        mockUsdt.mint(vm.addr(lenderPk2), INITIAL_DEPOSIT);

        // Register and create lending terms for two lenders
        registry.register("0xquantum3labs");
        uint256 term1 = lendingManager.createLendingTerm(1000, IHooks(address(0)));
        uint256 term2 = lendingManager.createLendingTerm(1000, IHooks(address(0)));

        // Deposit and delegate to term for lender 1
        mockUsdt.approve(address(assetManager), INITIAL_DEPOSIT);
        assetManager.deposit(address(mockUsdt), INITIAL_DEPOSIT);
        address usdtVaultAddr = assetManager.getVaultToken(address(mockUsdt));
        IERC4626 usdtVault = IERC4626(usdtVaultAddr);
        uint256 sharesOfUser1 = usdtVault.balanceOf(vm.addr(lenderPk1));
        uint256 usdtVaultAmountWithDecimals1 = sharesOfUser1 / 2;
        usdtVault.approve(address(lendingManager), usdtVaultAmountWithDecimals1);
        lendingManager.depositToTerm(term1, address(mockUsdt), usdtVaultAmountWithDecimals1);

        vm.stopBroadcast();

        vm.startBroadcast(lenderPk2);

        // Deposit and delegate to term for lender 2
        mockUsdt.approve(address(assetManager), INITIAL_DEPOSIT);
        assetManager.deposit(address(mockUsdt), INITIAL_DEPOSIT);
        uint256 sharesOfUser2 = usdtVault.balanceOf(vm.addr(lenderPk2));
        uint256 usdtVaultAmountWithDecimals2 = sharesOfUser2 / 2;
        usdtVault.approve(address(lendingManager), usdtVaultAmountWithDecimals2);
        lendingManager.depositToTerm(term2, address(mockUsdt), usdtVaultAmountWithDecimals2);

        vm.stopBroadcast();

        // Borrower 1 requests a loan
        vm.startBroadcast(borrowerPk1);
        LoanManager loanManager = LoanManager(getDeployment("LoanManager"));
        uint256 loanId1 =
            loanManager.requestLoan(getDeployment("MockUsdt"), LOAN_AMOUNT, block.timestamp + 1 days);
        vm.stopBroadcast();

        // Borrower 2 requests a loan
        vm.startBroadcast(borrowerPk2);
        uint256 loanId2 =
            loanManager.requestLoan(getDeployment("MockUsdt"), LOAN_AMOUNT, block.timestamp + 1 days);
        vm.stopBroadcast();

        // Lender 1 allocates to loan 1
        vm.startBroadcast(lenderPk1);
        loanManager.allocate(loanId1, term1, LOAN_AMOUNT);
        vm.stopBroadcast();

        // Lender 2 allocates to loan 2
        vm.startBroadcast(lenderPk2);
        loanManager.allocate(loanId2, term2, LOAN_AMOUNT);
        vm.stopBroadcast();

        // Borrower 1 executes the loan
        vm.startBroadcast(borrowerPk1);
        loanManager.executeLoan(loanId1);
        vm.stopBroadcast();

        // Borrower 2 executes the loan
        vm.startBroadcast(borrowerPk2);
        loanManager.executeLoan(loanId2);
        vm.stopBroadcast();

        // Borrowers repay loans
        uint256 interest = (LOAN_AMOUNT * 500) / BASIS_POINTS;
        mockUsdt.mint(vm.addr(borrowerPk1), interest);
        mockUsdt.mint(vm.addr(borrowerPk2), interest);

        vm.startBroadcast(borrowerPk1);
        mockUsdt.approve(address(assetManager), LOAN_AMOUNT + interest);
        loanManager.repay(loanId1);
        vm.stopBroadcast();

        vm.startBroadcast(borrowerPk2);
        mockUsdt.approve(address(assetManager), LOAN_AMOUNT + interest);
        loanManager.repay(loanId2);
        vm.stopBroadcast();

        // Lenders claim their profits
        vm.startBroadcast(lenderPk1);
        loanManager.claim(term1, loanId1);
        vm.stopBroadcast();

        vm.startBroadcast(lenderPk2);
        loanManager.claim(term2, loanId2);
        vm.stopBroadcast();
    }
}
