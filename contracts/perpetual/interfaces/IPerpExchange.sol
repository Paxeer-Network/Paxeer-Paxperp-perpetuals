// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IPerpExchange {
    // Position struct
    struct Position {
        uint256 id;
        address trader;
        address indexToken;
        bool isLong;
        uint256 size;
        uint256 collateral;
        uint256 avgPrice;
        uint256 entryFundingRate;
        uint256 reserveAmount;
        uint256 realisedPnl;
        uint256 lastUpdatedBlock;
    }

    // Events
    event PositionOpened(
        uint256 indexed positionId,
        address indexed trader,
        address indexed indexToken,
        bool isLong,
        uint256 size,
        uint256 collateral,
        uint256 avgPrice
    );

    event PositionClosed(
        uint256 indexed positionId,
        address indexed trader,
        uint256 size,
        uint256 collateral,
        uint256 avgPrice,
        int256 pnl,
        uint256 fee
    );

    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed trader,
        address indexed liquidator,
        uint256 size,
        uint256 collateral,
        int256 pnl,
        uint256 fee
    );

    event PositionIncreased(
        uint256 indexed positionId,
        uint256 collateralDelta,
        uint256 sizeDelta,
        uint256 price,
        uint256 fee
    );

    event PositionDecreased(
        uint256 indexed positionId,
        uint256 collateralDelta,
        uint256 sizeDelta,
        uint256 price,
        uint256 fee
    );

    // Main functions
    function openPosition(
        address _indexToken,
        uint256 _collateral,
        uint256 _sizeDelta,
        bool _isLong
    ) external returns (uint256 positionId);

    function closePosition(uint256 _positionId) external;

    function increasePosition(
        uint256 _positionId,
        uint256 _collateralDelta,
        uint256 _sizeDelta
    ) external;

    function decreasePosition(
        uint256 _positionId,
        uint256 _collateralDelta,
        uint256 _sizeDelta
    ) external;

    function liquidatePosition(uint256 _positionId) external;

    // View functions
    function getPosition(uint256 _positionId) external view returns (Position memory);
    function getPositionKey(address _trader, address _indexToken, bool _isLong) external pure returns (bytes32);
    function validateLiquidation(uint256 _positionId) external view returns (bool);
}
