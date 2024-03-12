pragma solidity 0.8.20;

import {ICore, PoolInitData} from "../interfaces/ICore.sol";
import {LibAppStorage, AppStorage, PoolStorage} from "../libraries/LibAppStorage.sol";
import {Base} from "./Base.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AdminFacet is ICore, Base {
    string public constant override name = "Core";

    function createPool(PoolInitData memory poolInitData) public override onlyRegisteredUser returns (uint256 poolId) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.poolCount++;
        poolId = s.poolCount;

        // create and setup the pool
        PoolStorage storage ps = s.pools[poolId];
        ps.name = poolInitData.name;
        ps.owner = msg.sender;
        ps.creditScore = poolInitData.creditScore;
        ps.maxAmountOfStakers = poolInitData.maxAmountOfStakers;
        ps.votingQuorum = poolInitData.votingQuorum;
        ps.maxPoolUsage = poolInitData.maxPoolUsage;
        ps.votingPowerCoolDown = poolInitData.votingPowerCoolDown;

        for (uint256 i = 0; i < poolInitData.supportedAssets.length; i++) {
            if (!s.supportedAssets[poolInitData.supportedAssets[i]]) {
                revert TokenNotSupported(poolInitData.initToken);
            }
            ps.supportedAssets[poolInitData.supportedAssets[i]] = true;
        }

        for (uint256 i = 0; i < poolInitData.supportedAgreements.length; i++) {
            if (!s.supportedAgreements[poolInitData.supportedAgreements[i]]) {
                revert AgreementNotSupported(poolInitData.supportedAgreements[i]);
            }
            ps.supportedAgreements[poolInitData.supportedAgreements[i]] = true;
        }

        if (!s.supportedAssets[poolInitData.initToken]) {
            revert TokenNotSupported(poolInitData.initToken);
        }

        IERC20(poolInitData.initToken).transferFrom(msg.sender, address(this), poolInitData.initAmount);

        s.balance[poolId][poolInitData.initToken] = poolInitData.initAmount;
    }
}
