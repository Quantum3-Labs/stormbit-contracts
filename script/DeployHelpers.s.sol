pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DeployHelpers is Script {
    struct NetworkConfig {
        address[] initialSupportedTokens;
        address governor;
        address owner;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 17000) {
            // holesky testnet
            activeNetworkConfig = getHoleskyConfig();
        } else {
            // devnet
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getActiveNetworkConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return activeNetworkConfig;
    }

    function getHoleskyConfig()
        public
        view
        returns (NetworkConfig memory networkConfig)
    {
        // update the tokens address
        address[] memory tokens = new address[](3);

        networkConfig = NetworkConfig({
            initialSupportedTokens: tokens,
            governor: address(0), // todo: change to real governor
            owner: address(0), // todo: change to real owner
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilConfig()
        public
        returns (NetworkConfig memory networkConfig)
    {
        if (activeNetworkConfig.initialSupportedTokens.length != 0) {
            return activeNetworkConfig;
        }
        // deploy 3 mock erc20 tokens
        vm.startBroadcast();
        ERC20Mock mockERC201 = new ERC20Mock();
        ERC20Mock mockERC202 = new ERC20Mock();
        ERC20Mock mockERC203 = new ERC20Mock();
        vm.stopBroadcast();

        address[] memory tokens = new address[](3);
        tokens[0] = address(mockERC201);
        tokens[1] = address(mockERC202);
        tokens[2] = address(mockERC203);

        networkConfig = NetworkConfig({
            initialSupportedTokens: tokens,
            governor: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }

    function logDeployment(string memory name, address addr) public view {
        console.log(name, " : ", addr);
    }
}
