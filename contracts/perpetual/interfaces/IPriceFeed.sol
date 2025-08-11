// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IPriceFeed {
    event PriceUpdate(address indexed token, uint256 price, uint256 timestamp);
    event OracleAdded(address indexed token, address indexed oracle);
    event OracleRemoved(address indexed token);

    function getPrice(address _token) external view returns (uint256);
    function getLatestPrice(address _token) external view returns (uint256, uint256);
    function setPrice(address _token, uint256 _price) external;
    function addOracle(address _token, address _oracle) external;
    function removeOracle(address _token) external;
    function isValidPrice(address _token) external view returns (bool);
    function getPriceDecimals() external view returns (uint8);
}
