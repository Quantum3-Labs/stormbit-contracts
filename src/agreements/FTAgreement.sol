pragma solidity ^0.8.21;

import "../AgreementBase.sol";
import "../interfaces/IStormBitLending.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

abstract contract FTAgreement is AgreementBase {}
