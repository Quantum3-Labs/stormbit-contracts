//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ILending, LoanRequestParams} from "../interfaces/ILending.sol";
import {LibAppStorage, AppStorage, PoolStorage} from "../libraries/LibAppStorage.sol";
import {LibLending} from "../libraries/LibLending.sol";
import {Base} from "./Base.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingFacet is ILending, Base {
    string public constant override name = "Lending";

    function requestLoan(uint256 poolId, LoanRequestParams memory loanParams) external returns (uint256) {}

    function deposit(uint256 poolId, uint256 amount, address token)
        external
        override
        onlyRegisteredUser
        returns (bool)
    {
        LibLending._deposit(poolId, amount, token);
    }

    function withdraw(uint256 poolId, uint256 amount, address token) external returns (bool) {}

    function castVote(uint256 poolId, uint256 loanId, bool vote) external returns (bool) {}

    function initAgreement(
        uint256 poolId,
        uint256 loanId,
        uint256 amount,
        address token,
        address agreement,
        bytes memory agreementCalldata
    ) external returns (bool) {}
}
