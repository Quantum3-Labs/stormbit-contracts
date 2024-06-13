pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {TestUtils} from "../Utils.t.sol";
import {DeployScript} from "../../script/Deploy.s.sol";
import {StormbitAssetManager} from "../../src/AssetManager.sol";
import {DeployHelpers} from "../../script/DeployHelpers.s.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract AssetManagerTest is TestUtils {
    DeployHelpers.NetworkConfig activeNetworkConfig;
    StormbitAssetManager assetManager;
    address[] supportedTokens;

    function setUp() public {
        DeployScript deployScript = new DeployScript();
        (activeNetworkConfig, assetManager) = deployScript.run();

        supportedTokens = activeNetworkConfig.initialSupportedTokens;
    }

    function testAddToken() public {
        _addSupportedTokens();
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            assert(assetManager.isTokenSupported(supportedTokens[i]));
        }
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address tokenVault = assetManager.getTokenVault(supportedTokens[i]);
            IERC4626 tokenVaultInstance = IERC4626(tokenVault);
            assert(tokenVaultInstance.asset() == supportedTokens[i]);
        }
    }

    function testDeposit() public {
        // add supported tokens to the asset manager
        _addSupportedTokens();

        // use the first token
        address token = supportedTokens[0];
        ERC20Mock tokenInstance = ERC20Mock(token);
        address vault = assetManager.getTokenVault(token);
        IERC4626 vaultInstance = IERC4626(vault);

        // mint some tokens to the user
        uint256 amount = 1000 * (10 ** tokenInstance.decimals());
        tokenInstance.mint(depositor, amount);

        vm.startPrank(depositor);
        tokenInstance.transfer(address(assetManager), amount);
        assetManager.deposit(token, amount);
        vm.stopPrank();

        // get the user shares
        uint256 shares = assetManager.getUserShares(token, depositor);
        uint256 expectedShares = vaultInstance.convertToShares(amount);

        assert(tokenInstance.balanceOf(vault) == amount);
        assert(tokenInstance.balanceOf(depositor) == 0);
        assert(shares == expectedShares);
    }

    function _addSupportedTokens() private {
        vm.startPrank(governor);
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            assetManager.addToken(supportedTokens[i]);
        }
        vm.stopPrank();
    }
}
