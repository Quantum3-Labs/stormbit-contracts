// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SetupTest} from "../Setup.t.sol";

contract AssetManagerTest is SetupTest {
    function setUp() public override {
        super.setUp();
    }

    function testDeposit() public {
        address depositor = depositor1;
        ERC20Mock token1 = token1;
        ERC20Mock token2 = token2;
        uint256 depositAmount = 1000;

        // Ensure depositor has enough tokens
        vm.startPrank(depositor);
        token1.approve(address(assetManager), depositAmount);
        token2.approve(address(assetManager), depositAmount);

        // Deposit the tokens
        assetManager.deposit(address(token1), depositAmount);
        assetManager.deposit(address(token2), depositAmount);
        vm.stopPrank();

        // Check that the deposit was successful
        uint256 vaultBalance = token1.balanceOf(address(vaultToken1));
        uint256 vaultBalance2 = token2.balanceOf(address(vaultToken2));
        uint256 depositorBalance = vaultToken1.balanceOf(depositor);
        uint256 depositorBalance2 = vaultToken2.balanceOf(depositor);

        assertEq(vaultBalance, depositAmount, "Vault should have the deposited amount");
        assertEq(vaultBalance2, depositAmount, "Vault should have the deposited amount");
    }
}
