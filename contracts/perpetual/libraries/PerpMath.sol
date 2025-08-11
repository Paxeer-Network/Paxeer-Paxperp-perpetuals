// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library PerpMath {
    uint256 internal constant WAD = 1e18;      // 18 decimals
    uint256 internal constant RAY = 1e27;      // 27 decimals
    uint256 internal constant PRECISION = 1e30; // 30 decimals for USD size

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function mulWad(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / WAD;
    }

    function divWad(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * WAD) / b;
    }

    function mulPrecision(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / PRECISION;
    }

    function divPrecision(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * PRECISION) / b;
    }

    // priceScale = 1e8 by default; convert price to 1e30 precision factor
    function priceToPrecision(uint256 price, uint8 priceDecimals) internal pure returns (uint256) {
        // convert price with priceDecimals to 1e30
        uint256 factor = 10 ** uint256(priceDecimals);
        // price * (1e30 / factor)
        return (price * (PRECISION / factor));
    }

    // Calculate PnL for a position sized in USD (1e30), using avgPrice and currentPrice (1e30)
    function calcPnl(bool isLong, uint256 sizeUsd, uint256 avgPrice, uint256 currentPrice) internal pure returns (int256) {
        if (sizeUsd == 0 || avgPrice == 0 || currentPrice == 0) return 0;
        if (isLong) {
            // pnl = sizeUsd * (currentPrice - avgPrice) / avgPrice
            if (currentPrice >= avgPrice) {
                uint256 gain = (sizeUsd * (currentPrice - avgPrice)) / avgPrice;
                return int256(gain);
            } else {
                uint256 loss = (sizeUsd * (avgPrice - currentPrice)) / avgPrice;
                return -int256(loss);
            }
        } else {
            // short: pnl = sizeUsd * (avgPrice - currentPrice) / avgPrice
            if (avgPrice >= currentPrice) {
                uint256 gain = (sizeUsd * (avgPrice - currentPrice)) / avgPrice;
                return int256(gain);
            } else {
                uint256 loss = (sizeUsd * (currentPrice - avgPrice)) / avgPrice;
                return -int256(loss);
            }
        }
    }
}
