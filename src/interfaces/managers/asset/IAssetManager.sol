pragma solidity ^0.8.21;

/// @author Quantum3 Labs
/// @title Stormbit Asset Manager Interface
/// TODO split into different interfaces according to funcionality
interface IAssetManager {
    event AddToken(address indexed token, address indexed vault);

    event RemoveToken(address indexed token, address indexed vault);

    // TODO : change this to asset vault later
    function addToken(address _asset) external;

    function removeToken(address _asset) external;
}
