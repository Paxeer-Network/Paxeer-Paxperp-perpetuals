// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../interfaces/IPriceFeed.sol";

contract PriceFeed is IPriceFeed {
    address public owner;
    uint8 public constant PRICE_DECIMALS = 8; // e.g., 1e8 like Chainlink

    struct TokenOracle {
        address oracle; // allowed poster or Chainlink aggregator in future
        uint256 lastPrice; // price with PRICE_DECIMALS
        uint256 lastUpdatedAt; // timestamp
        bool exists;
    }

    mapping(address => TokenOracle) public tokenOracles;

    modifier onlyOwner() { require(msg.sender == owner, "OwnerOnly"); _; }
    modifier onlyOracle(address token) {
        require(tokenOracles[token].oracle == address(0) || msg.sender == tokenOracles[token].oracle || msg.sender == owner, "NotOracle"); _;
    }

    constructor() { owner = msg.sender; }

    function addOracle(address _token, address _oracle) external onlyOwner {
        tokenOracles[_token].oracle = _oracle;
        tokenOracles[_token].exists = true;
        emit OracleAdded(_token, _oracle);
    }

    function removeOracle(address _token) external onlyOwner {
        delete tokenOracles[_token];
        emit OracleRemoved(_token);
    }

    function setPrice(address _token, uint256 _price) external onlyOracle(_token) {
        require(_price > 0, "BadPrice");
        TokenOracle storage t = tokenOracles[_token];
        require(t.exists || t.oracle == address(0) || msg.sender == owner, "NoToken");
        t.lastPrice = _price;
        t.lastUpdatedAt = block.timestamp;
        emit PriceUpdate(_token, _price, block.timestamp);
    }

    function getPrice(address _token) external view returns (uint256) {
        TokenOracle memory t = tokenOracles[_token];
        require(t.lastPrice > 0, "NoPrice");
        return t.lastPrice;
    }

    function getLatestPrice(address _token) external view returns (uint256, uint256) {
        TokenOracle memory t = tokenOracles[_token];
        require(t.lastPrice > 0, "NoPrice");
        return (t.lastPrice, t.lastUpdatedAt);
    }

    function isValidPrice(address _token) external view returns (bool) {
        TokenOracle memory t = tokenOracles[_token];
        if (t.lastPrice == 0) return false;
        // consider stale if older than 10 minutes
        return block.timestamp - t.lastUpdatedAt <= 600;
    }

    function getPriceDecimals() external pure returns (uint8) { return PRICE_DECIMALS; }

    function transferOwnership(address _owner) external onlyOwner { owner = _owner; }
}
