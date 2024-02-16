// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
    uint256 public supply;

    constructor() ERC721("MockNFT", "MNFT") {}

    function mint() public {
        require(supply < 100, "MockNFT: max supply reached");
        supply++;
        _safeMint(msg.sender, supply);
    }
}
