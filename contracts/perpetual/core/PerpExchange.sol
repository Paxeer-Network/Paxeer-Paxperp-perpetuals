// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../interfaces/IPerpExchange.sol";
import "../interfaces/IPriceFeed.sol";
import "../interfaces/IVault.sol";
import "../libraries/PerpMath.sol";

contract PerpExchange is IPerpExchange {
    using PerpMath for uint256;

    address public owner;
    IVault public vault;
    IPriceFeed public priceFeed;

    uint256 public nextPositionId = 1;

    // market settings per index token
    struct MarketConfig {
        bool isActive;
        uint256 maxLeverage; // e.g., 50e18 for 50x
        uint256 maintenanceMarginBps; // e.g., 50 = 0.5%
        uint256 tradingFeeBps; // e.g., 10 = 0.1%
    }

    mapping(address => MarketConfig) public markets;
    mapping(uint256 => Position) public positions; // id => position
    mapping(bytes32 => uint256) public positionKeyToId; // key => id

    event MarketUpdated(address indexed token, bool isActive, uint256 maxLev, uint256 mmBps, uint256 feeBps);

    modifier onlyOwner() { require(msg.sender == owner, "OwnerOnly"); _; }

    constructor(address _vault, address _priceFeed) {
        owner = msg.sender;
        vault = IVault(_vault);
        priceFeed = IPriceFeed(_priceFeed);
    }

    function setMarket(address _indexToken, bool _isActive, uint256 _maxLev, uint256 _mmBps, uint256 _feeBps) external onlyOwner {
        markets[_indexToken] = MarketConfig({
            isActive: _isActive,
            maxLeverage: _maxLev,
            maintenanceMarginBps: _mmBps,
            tradingFeeBps: _feeBps
        });
        emit MarketUpdated(_indexToken, _isActive, _maxLev, _mmBps, _feeBps);
    }

    function getPositionKey(address _trader, address _indexToken, bool _isLong) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_trader, _indexToken, _isLong));
    }

    function getPosition(uint256 _positionId) external view returns (Position memory) {
        return positions[_positionId];
    }

    function openPosition(
        address _indexToken,
        uint256 _collateral,
        uint256 _sizeDelta,
        bool _isLong
    ) external returns (uint256 positionId) {
        MarketConfig memory m = markets[_indexToken];
        require(m.isActive, "MarketInactive");
        require(_collateral > 0 && _sizeDelta > 0, "BadParams");
        require(_sizeDelta >= _collateral, "LeverageTooLow");
        require((_sizeDelta * 1e18) / _collateral <= m.maxLeverage, "LeverageTooHigh");

        // transfer from user's vault trading balance (in production you'd integrate a settlement token)
        vault.transferFromTrading(msg.sender, _collateral);

        (uint256 price, ) = priceFeed.getLatestPrice(_indexToken);
        uint256 priceP = PerpMath.priceToPrecision(price, priceFeed.getPriceDecimals());

        uint256 fee = (_sizeDelta * m.tradingFeeBps) / 10000;

        positionId = nextPositionId++;
        Position storage p = positions[positionId];
        p.id = positionId;
        p.trader = msg.sender;
        p.indexToken = _indexToken;
        p.isLong = _isLong;
        p.size = _sizeDelta; // in 1e30 USD units assumed
        p.collateral = _collateral - fee;
        p.avgPrice = priceP;
        p.entryFundingRate = 0; // future use
        p.reserveAmount = 0;
        p.realisedPnl = 0;
        p.lastUpdatedBlock = block.number;

        bytes32 key = getPositionKey(msg.sender, _indexToken, _isLong);
        positionKeyToId[key] = positionId;

        emit PositionOpened(positionId, msg.sender, _indexToken, _isLong, p.size, p.collateral, p.avgPrice);
    }

    function closePosition(uint256 _positionId) external {
        Position storage p = positions[_positionId];
        require(p.trader == msg.sender, "NotOwner");
        require(p.size > 0, "NoPosition");

        (uint256 price, ) = priceFeed.getLatestPrice(p.indexToken);
        uint256 priceP = PerpMath.priceToPrecision(price, priceFeed.getPriceDecimals());

        int256 pnl = PerpMath.calcPnl(p.isLong, p.size, p.avgPrice, priceP);

        uint256 feeBps = markets[p.indexToken].tradingFeeBps;
        uint256 fee = (p.size * feeBps) / 10000;

        uint256 payout;
        if (pnl >= 0) {
            payout = p.collateral + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            require(p.collateral >= loss, "Liquidatable");
            payout = p.collateral - loss;
        }
        require(payout >= fee, "FeeExceedsPayout");
        payout -= fee;

        // pay back to trading balance
        vault.transferToTrading(p.trader, payout);

        emit PositionClosed(p.id, p.trader, p.size, p.collateral, p.avgPrice, pnl, fee);

        // clear position
        delete positionKeyToId[getPositionKey(p.trader, p.indexToken, p.isLong)];
        delete positions[_positionId];
    }

    function increasePosition(uint256 _positionId, uint256 _collateralDelta, uint256 _sizeDelta) external {
        Position storage p = positions[_positionId];
        require(p.trader == msg.sender, "NotOwner");
        require(_collateralDelta > 0 || _sizeDelta > 0, "NothingToDo");

        if (_collateralDelta > 0) {
            vault.transferFromTrading(msg.sender, _collateralDelta);
            p.collateral += _collateralDelta;
        }
        if (_sizeDelta > 0) {
            uint256 fee = (_sizeDelta * markets[p.indexToken].tradingFeeBps) / 10000;
            p.size += _sizeDelta;
            require((p.size * 1e18) / p.collateral <= markets[p.indexToken].maxLeverage, "LevTooHigh");
            require(p.collateral > fee, "FeeTooHigh");
            p.collateral -= fee;
        }
        p.lastUpdatedBlock = block.number;

        (uint256 price, ) = priceFeed.getLatestPrice(p.indexToken);
        emit PositionIncreased(_positionId, _collateralDelta, _sizeDelta, price, 0);
    }

    function decreasePosition(uint256 _positionId, uint256 _collateralDelta, uint256 _sizeDelta) external {
        Position storage p = positions[_positionId];
        require(p.trader == msg.sender, "NotOwner");
        require(_collateralDelta > 0 || _sizeDelta > 0, "NothingToDo");
        require(_collateralDelta <= p.collateral && _sizeDelta <= p.size, "TooMuch");

        p.collateral -= _collateralDelta;
        p.size -= _sizeDelta;
        require((p.size == 0) || ((p.size * 1e18) / p.collateral <= markets[p.indexToken].maxLeverage), "LevTooHigh");
        vault.transferToTrading(msg.sender, _collateralDelta);
        p.lastUpdatedBlock = block.number;

        (uint256 price, ) = priceFeed.getLatestPrice(p.indexToken);
        emit PositionDecreased(_positionId, _collateralDelta, _sizeDelta, price, 0);
    }

    function validateLiquidation(uint256 _positionId) public view returns (bool) {
        Position memory p = positions[_positionId];
        if (p.size == 0) return false;
        (uint256 price, ) = priceFeed.getLatestPrice(p.indexToken);
        uint256 priceP = PerpMath.priceToPrecision(price, priceFeed.getPriceDecimals());
        int256 pnl = PerpMath.calcPnl(p.isLong, p.size, p.avgPrice, priceP);
        uint256 mmBps = markets[p.indexToken].maintenanceMarginBps;
        uint256 maintenance = (p.size * mmBps) / 10000; // in 1e30
        if (pnl < 0) {
            uint256 loss = uint256(-pnl);
            return loss >= p.collateral || (p.collateral - loss) <= maintenance;
        }
        return p.collateral <= maintenance;
    }

    function liquidatePosition(uint256 _positionId) external {
        require(validateLiquidation(_positionId), "NotLiquidatable");
        Position memory p = positions[_positionId];
        // send remaining collateral to vault (could split between liquidator/treasury)
        vault.transferToTrading(p.trader, p.collateral / 10); // reward user with 10% remainder
        emit PositionLiquidated(p.id, p.trader, msg.sender, p.size, p.collateral, 0, 0);
        delete positionKeyToId[getPositionKey(p.trader, p.indexToken, p.isLong)];
        delete positions[_positionId];
    }

    function transferOwnership(address _owner) external onlyOwner { owner = _owner; }
}
