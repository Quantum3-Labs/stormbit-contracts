pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

import {IAdmin} from "../src/interfaces/IAdmin.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";
import {MockToken} from "../src/mocks/MockToken.sol";
import {ILending} from "../src/interfaces/ILending.sol";
import {IRegistry} from "../src/interfaces/IRegistry.sol";

contract SomeScript is Script {
    address public stormbit = 0x6bdB8053b6fb40DFF3cBf7D7f9A2Cb108CD3F772;
    uint256 public poolId = 1;
    MockToken usdt = MockToken(0xd53631221589444F712c30945294b7DcaB2f1A28);
    BaseVault usdtVault = BaseVault(0x0367dAA24B948A833dFC1783FE6ef42b351e7706);

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY_2");
        address staker = vm.addr(pk);
        vm.startBroadcast(pk);
        IRegistry(stormbit).register("staker");
        usdt.mint(staker, 1000 * 10 ** 18);
        usdt.approve(address(usdtVault), 100 * 10 ** 18);
        usdtVault.deposit(100 * 10 ** 18, staker);
        usdtVault.approve(address(stormbit), 100 * 10 ** 18);
        ILending(stormbit).deposit(poolId, 100 * 10 ** 18, address(usdtVault));
        vm.stopBroadcast;
    }

    function _changeGovernor(address newGovernor) public {
        IAdmin(stormbit).setNewGovernor(newGovernor);
    }
}
