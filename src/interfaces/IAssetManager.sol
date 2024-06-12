pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Asset Manager Interface
/// TODO split into different interfaces according to funcionality
interface IAssetManager {
    // TODO : change this to asset vault later
    function addToken(address _asset) external;

    function removeToken(address _asset) external;
}
