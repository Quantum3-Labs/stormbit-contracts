pragma solidity ^0.8.21;

import "forge-std/test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {StormbitAssetManager} from "../src/AssetManager.sol";
import {StormbitLendingManager} from "../src/LendingManager.sol";
import {StormbitLoanManager} from "../src/LoanManager.sol";
import {TestUtils} from "./Utils.t.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";

contract SetupTest is TestUtils {
    ERC20Mock token1;
    ERC20Mock token2;
    ERC20Mock token3;

    StormbitAssetManager assetManager;
    StormbitLendingManager lendingManager;
    StormbitLoanManager loanManager;

    BaseVault vaultToken1;
    BaseVault vaultToken2;
    BaseVault vaultToken3;

    address[] supportedTokens;

    function setUpEnvironment() public {
        token1 = new ERC20Mock();
        token2 = new ERC20Mock();
        token3 = new ERC20Mock();

        supportedTokens = [address(token1), address(token2), address(token3)];
        assetManager = new StormbitAssetManager(governor, owner);
        lendingManager = new StormbitLendingManager(governor);
        loanManager = new StormbitLoanManager(governor);

        vm.startPrank(owner);
        assetManager.initialize(address(loanManager), address(lendingManager));
        lendingManager.initialize(address(assetManager), address(loanManager));
        loanManager.initialize(address(assetManager), address(lendingManager));
        vm.stopPrank();

        _addSupportedTokens();
        _mintAllTokens();
        _setUpTokenVaults();
    }

    function _addSupportedTokens() private {
        vm.startPrank(governor);
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            assetManager.addToken(supportedTokens[i]);
        }
        vm.stopPrank();
    }

    function _setUpTokenVaults() private {
        vaultToken1 = BaseVault(assetManager.getTokenVault(address(token1)));
        vaultToken2 = BaseVault(assetManager.getTokenVault(address(token2)));
        vaultToken3 = BaseVault(assetManager.getTokenVault(address(token3)));
    }

    function _mintAllTokens() private {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            ERC20Mock token = ERC20Mock(supportedTokens[i]);
            token.mint(
                depositor1,
                initialTokenBalance * (10 ** token.decimals())
            );
            token.mint(
                depositor2,
                initialTokenBalance * (10 ** token.decimals())
            );
            token.mint(
                depositor3,
                initialTokenBalance * (10 ** token.decimals())
            );
        }
    }

    function _fundVault() internal {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            vm.startPrank(funder);
            // deposit some token to vault by asset manager
            ERC20Mock token = ERC20Mock(supportedTokens[i]);
            uint256 depositAmount = initialFundBalance *
                (10 ** token.decimals());
            token.approve(address(assetManager), depositAmount);
            assetManager.deposit(supportedTokens[i], depositAmount);
            vm.stopPrank();
        }
    }
}
