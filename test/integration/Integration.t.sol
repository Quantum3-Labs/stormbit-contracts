pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SetupTest} from "../Setup.t.sol";

contract IntegrationTest is SetupTest {
    function setUp() public {
        SetupTest.setUpEnvironment();
    }
}
