pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

import {IAdmin} from "../src/interfaces/IAdmin.sol";

contract DeployScript is Script {
    address public diamond = 0xA44f9778e078bB6DA8ec99f31Eb0ff5f0941A516;

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        _changeGovernor(0xDe3089d40F3491De794fBb1ECA109fAc36F889d0);
        vm.stopBroadcast;
    }

    function _changeGovernor(address newGovernor) public {
        IAdmin(diamond).setNewGovernor(newGovernor);
    }
}
