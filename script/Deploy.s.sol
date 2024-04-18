pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {DiamondProxy, LibDiamond} from "../src/DiamondProxy.sol";
import {DiamondInit, InitParams} from "../src/initializers/DiamondInit.sol";

import {AdminFacet} from "../src/facets/AdminFacet.sol";
import {CoreFacet, PoolInitData} from "../src/facets/CoreFacet.sol";
import {LendingFacet} from "../src/facets/LendingFacet.sol";
import {RegistryFacet} from "../src/facets/RegistryFacet.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";
import {MockToken} from "../src/mocks/MockToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployScript is Script {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address governor = vm.addr(pk);
        vm.startBroadcast(pk);

        // deploy mocks

        // ------- MOCKS --------
        MockToken usdt = new MockToken("US Dollar", "USDT");
        // ------- VAULTS --------
        BaseVault usdtVault = new BaseVault(IERC20(usdt), governor, "USDT Vault", "sUSDT");

        AdminFacet adminFacet = new AdminFacet();
        CoreFacet coreFacet = new CoreFacet();
        LendingFacet lendingFacet = new LendingFacet();
        RegistryFacet registryFacet = new RegistryFacet();
        DiamondInit diamondInit = new DiamondInit();

        DiamondProxy stormbit;

        // ------- ADMIN FACET SELECTORS -----------
        bytes4[] memory adminFacetFunctionSelectors = new bytes4[](3);
        adminFacetFunctionSelectors[0] = adminFacet.setNewGovernor.selector;
        adminFacetFunctionSelectors[1] = adminFacet.governor.selector;
        adminFacetFunctionSelectors[2] = adminFacet.addSupportedAsset.selector;

        // ------- REGISTRY FACET SELECTORS -----------
        bytes4[] memory registryFacetFunctionSelectors = new bytes4[](3);
        registryFacetFunctionSelectors[0] = registryFacet.register.selector;
        registryFacetFunctionSelectors[1] = registryFacet.isRegistered.selector;
        registryFacetFunctionSelectors[2] = registryFacet.isUsernameUsed.selector;

        // ------- CORE FACET SELECTORS -----------
        bytes4[] memory coreFacetFunctionSelectors = new bytes4[](1);
        coreFacetFunctionSelectors[0] = coreFacet.createPool.selector;

        // ------- LENDING FACET SELECTORS -----------
        bytes4[] memory lendingFacetFunctionSelectors = new bytes4[](3);
        lendingFacetFunctionSelectors[0] = lendingFacet.deposit.selector;
        lendingFacetFunctionSelectors[1] = lendingFacet.withdraw.selector;
        lendingFacetFunctionSelectors[2] = lendingFacet.getTotalShares.selector;

        // ------- DIAMOND CUTS --------
        LibDiamond.FacetCut[] memory _diamondCut = new LibDiamond.FacetCut[](4);

        _diamondCut[0] = LibDiamond.FacetCut({
            facetAddress: address(adminFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: adminFacetFunctionSelectors
        });

        _diamondCut[1] = LibDiamond.FacetCut({
            facetAddress: address(coreFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: coreFacetFunctionSelectors
        });

        _diamondCut[2] = LibDiamond.FacetCut({
            facetAddress: address(lendingFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: lendingFacetFunctionSelectors
        });

        _diamondCut[3] = LibDiamond.FacetCut({
            facetAddress: address(registryFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: registryFacetFunctionSelectors
        });

        // ------- DIAMOND INIT PARAMS --------
        InitParams memory _initParams = InitParams({initialGovernor: governor});
        stormbit = new DiamondProxy(
            _diamondCut, address(diamondInit), abi.encodeWithSelector(DiamondInit.initialize.selector, _initParams)
        );

        AdminFacet(address(stormbit)).setNewGovernor(governor);

        // ------- Aditional Setup --------
        AdminFacet(address(stormbit)).addSupportedAsset(address(usdtVault));
        vm.stopBroadcast;

        // ------- Mint tokens ------------
        usdt.mint(governor, 1000 * 10 ** 18);
        usdt.approve(address(usdtVault), 100 * 10 ** 18);
        usdtVault.deposit(100 * 10 ** 18, governor);

        // ------- Register in the registry ------------
        RegistryFacet(address(stormbit)).register("governor");

        // Create pools
        usdtVault.approve(address(stormbit), 100 * 10 ** 18);

        uint256 poolId = CoreFacet(address(stormbit)).createPool(
            PoolInitData({
                name: "Test Pool 1",
                creditScore: 0,
                maxAmountOfStakers: 10,
                votingQuorum: 5,
                maxPoolUsage: 100,
                votingPowerCoolDown: 10,
                assets: 100 * 10 ** 18,
                asset: address(usdtVault)
            })
        );

        console.log("Pool ID: %s", poolId);
        console.log("Stormbit deployed at: %s", address(stormbit));
        console.log("Deplyed at block %s", block.number);
        console.log("usdtVault deployed at: %s", address(usdtVault));
        console.log("usdt deployed at: %s", address(usdt));
        console.log("user name used yes no", RegistryFacet(address(stormbit)).isUsernameUsed("governor"));
        console.log("user registered yes no", RegistryFacet(address(stormbit)).isRegistered(governor));

        // ------- End of deployment ------------
    }
}
