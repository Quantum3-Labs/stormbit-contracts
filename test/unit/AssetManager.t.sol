pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SetupTest} from "../Setup.t.sol";

contract AssetManagerTest is SetupTest {
// function testInitialize() public view {
//     assert(address(assetManager.loanManager()) == address(loanManager));
//     assert(
//         address(assetManager.lendingManager()) == address(lendingManager)
//     );
// }
// function testAddToken() public view {
//     for (uint256 i = 0; i < supportedTokens.length; i++) {
//         assert(assetManager.isTokenSupported(supportedTokens[i]));
//     }
//     for (uint256 i = 0; i < supportedTokens.length; i++) {
//         address tokenVault = assetManager.getTokenVault(supportedTokens[i]);
//         IERC4626 tokenVaultInstance = IERC4626(tokenVault);
//         assert(tokenVaultInstance.asset() == supportedTokens[i]);
//     }
// }
// function testDeposit() public {
//     // use the first token
//     address token = supportedTokens[0];
//     ERC20Mock tokenInstance = ERC20Mock(token);
//     address vault = assetManager.getTokenVault(token);
//     uint256 amount = initialTokenBalance * (10 ** tokenInstance.decimals());
//     vm.startPrank(depositor1);
//     tokenInstance.approve(address(assetManager), amount);
//     assetManager.deposit(token, amount);
//     vm.stopPrank();
//     // get the user shares
//     uint256 shares = assetManager.getUserShares(token, depositor1);
//     uint256 expectedShares = assetManager.convertToShares(token, amount);
//     assert(tokenInstance.balanceOf(vault) == amount);
//     assert(tokenInstance.balanceOf(depositor1) == 0);
//     assert(shares == expectedShares);
// }
// function depositFrom() public {
//     address token = supportedTokens[0];
//     ERC20Mock tokenInstance = ERC20Mock(token);
//     address vault = assetManager.getTokenVault(token);
//     uint256 amount = initialTokenBalance * (10 ** tokenInstance.decimals());
//     // depositor1 deposit for depositor2
//     vm.startPrank(depositor1);
//     tokenInstance.approve(address(assetManager), amount);
//     assetManager.depositFrom(token, amount, depositor1, depositor2);
//     vm.stopPrank();
//     // get depositor1 shares
//     uint256 shares1 = assetManager.getUserShares(token, depositor1);
//     uint256 expectedShares1 = 0;
//     // get depositor2 shares
//     uint256 shares2 = assetManager.getUserShares(token, depositor2);
//     uint256 expectedShares2 = assetManager.convertToShares(token, amount);
//     assert(tokenInstance.balanceOf(vault) == amount);
//     assert(tokenInstance.balanceOf(depositor1) == 0);
//     assert(tokenInstance.balanceOf(depositor2) == 0);
//     assert(shares1 == expectedShares1);
//     assert(shares2 == expectedShares2);
// }
}
