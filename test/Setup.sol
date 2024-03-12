pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DiamondProxy, LibDiamond} from "../src/DiamondProxy.sol";
import {DiamondInit, InitParams} from "../src/initializers/DiamondInit.sol";
import {AdminFacet} from "../src/facets/AdminFacet.sol";

contract Setup is Test {
    DiamondProxy public stormbit;
    DiamondInit public diamondInit;
    AdminFacet public adminFacet;

    /// @dev initial config params
    address governor = makeAddr("governor");

    function setUp() public {
        adminFacet = new AdminFacet();
        diamondInit = new DiamondInit();

        // ------- ADMIN FACET SELECTORS -----------
        bytes4[] memory adminFacetFunctionSelectors = new bytes4[](2);
        adminFacetFunctionSelectors[0] = adminFacet.setNewGovernor.selector;
        adminFacetFunctionSelectors[1] = adminFacet.governor.selector;

        // ------- DIAMOND CUTS --------
        LibDiamond.FacetCut[] memory _diamondCut = new LibDiamond.FacetCut[](1);

        _diamondCut[0] = LibDiamond.FacetCut({
            facetAddress: address(adminFacet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: adminFacetFunctionSelectors
        });

        // ------- DIAMOND INIT PARAMS --------
        InitParams memory _initParams = InitParams({initialGovernor: governor});
        stormbit = new DiamondProxy(
            _diamondCut, address(diamondInit), abi.encodeWithSelector(DiamondInit.initialize.selector, _initParams)
        );
    }
}
