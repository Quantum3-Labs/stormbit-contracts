// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {MockToken} from "src/mocks/MockToken.sol";
import {StormbitAssetManager} from "../src/AssetManager.sol";
import {StormbitLendingManager} from "../src/LendingManager.sol";
import {StormbitLoanManager} from "../src/LoanManager.sol";
import {DeployHelpers} from "script/DeployHelpers.s.sol";

contract Deploy is DeployHelpers {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        address deployer = vm.addr(pk);

        // TODO add checks when on anvil or testnet should be diff to mainnet
        MockToken mockUsdt = new MockToken("USD Tether", "USDT");
        MockToken mockDai = new MockToken("Dai Stablecoin", "DAI");
        MockToken mockUsdc = new MockToken("USD Coin ", "USDC");

        StormbitAssetManager assetManager = new StormbitAssetManager(deployer);
        StormbitLendingManager lendingManager = new StormbitLendingManager(deployer);
        StormbitLoanManager loanManager = new StormbitLoanManager(deployer);

        assetManager.initialize(address(loanManager), address(lendingManager));
        lendingManager.initialize(address(assetManager), address(loanManager));
        loanManager.initialize(address(assetManager), address(lendingManager));

        // add supported tokens
        assetManager.addToken(address(mockUsdt));
        assetManager.addToken(address(mockDai));
        assetManager.addToken(address(mockUsdc));

        vm.stopBroadcast();

        deployments.push(Deployment("AssetManager", address(assetManager)));
        deployments.push(Deployment("LendingManager", address(lendingManager)));
        deployments.push(Deployment("LoanManager", address(loanManager)));
        deployments.push(Deployment("MockUsdt", address(mockUsdt)));
        deployments.push(Deployment("MockDai", address(mockDai)));
        deployments.push(Deployment("MockUsdc", address(mockUsdc)));

        exportDeployments();

        getDeployment("AssetManager");
    }
}
