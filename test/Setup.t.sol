pragma solidity ^0.8.21;

import "forge-std/test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {StormbitAssetManager} from "../src/AssetManager.sol";
import {TestUtils} from "./Utils.t.sol";

contract SetupTest is TestUtils {
    ERC20Mock token1;
    ERC20Mock token2;
    ERC20Mock token3;
    StormbitAssetManager assetManager;
    address[] supportedTokens;

    function setUpEnvironment() public {
        token1 = new ERC20Mock();
        token2 = new ERC20Mock();
        token3 = new ERC20Mock();

        supportedTokens = [address(token1), address(token2), address(token3)];
        assetManager = new StormbitAssetManager(governor);
        _addSupportedTokens();
    }

    function _addSupportedTokens() private {
        vm.startPrank(governor);
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            assetManager.addToken(supportedTokens[i]);
        }
        vm.stopPrank();
    }
}
