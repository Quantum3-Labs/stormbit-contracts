// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// an ERC4626 with an underlying asset and with a fee for each deposit, fee is credited to StormBit Core

// TO DO : balance the interest rate model
// ----- : interest paid by protocol to lenders <= interest paid by borrowers to protocol
// ----- : reserve factor => % of interest paid by borrowers that goes to the protocol


contract StormBitERC4626 is ERC4626 {
    IERC20 private _underlyingToken;
    uint256 public totalDeposits;
    uint256 public totalBorrowed;

    constructor(IERC20 underlyingToken) ERC4626(underlyingToken) ERC20("StormBitERC4626", "STB4626") {
        _underlyingToken = underlyingToken;
        _mint(msg.sender, 10000000);
    }

    // Interest rate following Compound model
    // Lenders earn interest based on the liquidity they provide.
    // Borrowers pay interest on their loan.
    // How is the spread calculated ? => Interet earned by the protocol

    function deposit(uint256 _amount) external {
        _underlyingToken.transferFrom(msg.sender, address(this), _amount);  
        totalDeposits += _amount;
    }

    function borrow(uint256 _amount) external {
        require(_underlyingToken.balanceOf(address(this)) >= _amount, "Not enough liquidity");
        _underlyingToken.transfer(msg.sender, _amount);
        totalBorrowed += _amount;
    }


    /**
     * @notice Returns the utilization of the pool
     *     @dev utilization =  borrowed / total deposits
     */
    function getUtilization() public view returns (uint256) {
        uint256 utilization = totalBorrowed / totalDeposits;
        return utilization; 
    }

    /**
     * @notice returns intereste rates 
     *     @dev  interest rates are calculated based on the utilization of the pool
     */
    function getInterestRates() public view returns (uint256) {
        return 1;
    }

    /**
     * @notice returns the supply rate
     *     @dev  supply rate is interest rate for lenders
     */
    function getSupplyRate() public view returns (uint256) {
        return getInterestRates() * getUtilization();
    }
}
