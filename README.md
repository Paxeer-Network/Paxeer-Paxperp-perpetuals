# ⚡ DewPerp - Decentralized Perpetual Futures

[![Solidity](https://img.shields.io/badge/Solidity-^0.8.30-blue.svg)](https://soliditylang.org/)
[![Network](https://img.shields.io/badge/Network-Paxeer-green.svg)](https://paxeer.app)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

DewPerp is a decentralized perpetual futures trading platform built on Paxeer Network, enabling users to trade synthetic assets with leverage using real-time price feeds from oracles.

## 🚀 Features

### Core Trading Features
- **Perpetual Futures**: Trade synthetic BTC/USD, ETH/USD, and other pairs
- **High Leverage**: Up to 50x leverage (configurable per market)
- **Long & Short Positions**: Trade both directions with equal ease
- **Real-time Pricing**: Oracle-based price feeds with staleness protection
- **Cross & Isolated Margin**: Flexible margin management

### Advanced Features
- **Position Management**: Increase/decrease position size and collateral
- **Liquidation Engine**: Automated liquidation when positions become unsafe
- **Funding Rates**: Auto-balancing mechanism between longs and shorts (future)
- **Insurance Fund**: Protocol reserve for extreme market conditions (future)

### Risk Management
- **Maintenance Margin**: Configurable per market (default 0.5%)
- **Liquidation Threshold**: Automatic position closure at risk levels
- **Trading Fees**: 0.1% on position size
- **Max Position Limits**: Per-user and global position limits (future)

## 🏗️ Architecture

### Core Contracts

1. **PerpExchange** (`core/PerpExchange.sol`) - Main trading logic and position management
2. **Vault** (`core/Vault.sol`) - Collateral management and accounting
3. **PriceFeed** (`oracle/PriceFeed.sol`) - Oracle price aggregation
4. **PositionManager** (future) - Advanced position tracking
5. **LiquidationEngine** (future) - Automated liquidation system

### Libraries

- **PerpMath** (`libraries/PerpMath.sol`) - Fixed-point mathematics for precise calculations

## 📋 Deployed Contracts (Paxeer Network)

| Contract | Address | Purpose |
|----------|---------|---------|
| **PriceFeed** | `0xbFb451a7134bF3ec098B02cbD700ABCE61d5eBB9` | Oracle aggregator |
| **Vault** | `0x3739824f9c01a8c24cfCd852fFE71355487f3Ce0` | Collateral management |
| **PerpExchange** | `0x7E98273FBb3D2551b01bBAf54a9d0Ef8CC9Ecc44` | Main trading contract |

### Network Configuration
- **Network**: Paxeer Network
- **Chain ID**: 80000
- **RPC URL**: `https://rpc-paxeer-network-djjz47ii4b.t.conduit.xyz/DgdWRnqiV7UGiMR2s9JPMqto415SW9tNG`
- **Explorer**: https://paxscan.paxeer.app:443

### Supported Markets

| Market | Index Token | Max Leverage | Maintenance Margin | Trading Fee |
|--------|-------------|--------------|-------------------|-------------|
| **WETH/USD** | `0xD0C1a714c46c364DBDd4E0F7b0B6bA5354460dA7` | 50x | 0.5% | 0.1% |

*Current ETH Price: $4,230 USD*

## 🚀 Quick Start

### Prerequisites

- Node.js 16+
- Hardhat
- Paxeer Network RPC access
- Basic understanding of perpetual futures

### Installation

```bash
npm install
```

### Compilation

```bash
npx hardhat compile
```

### Deployment

```bash
npx hardhat run scripts/deployPerp.js --network paxeer-network
```

### Update Prices

```bash
npx hardhat run scripts/updatePerpPrice.js --network paxeer-network
```

## 📊 Trading Guide

### Position Structure

```solidity
struct Position {
    uint256 id;           // Unique position ID
    address trader;       // Position owner
    address indexToken;   // Underlying asset (WETH)
    bool isLong;         // Long (true) or Short (false)
    uint256 size;        // Position size in USD (1e30)
    uint256 collateral;  // Collateral amount (1e30)
    uint256 avgPrice;    // Average entry price (1e30)
    uint256 entryFundingRate; // Entry funding rate
    uint256 lastUpdatedBlock;  // Last update block
}
```

### Opening a Position

```javascript
// Example: Open a 10x long position on WETH/USD
const collateral = ethers.parseEther("1000"); // 1000 USD collateral (1e30)
const size = ethers.parseEther("10000");      // 10000 USD position size (1e30)
const isLong = true;                          // Long position

await perpExchange.openPosition(
    WETH_ADDRESS,
    collateral,
    size,
    isLong
);
```

### Closing a Position

```javascript
// Close position by ID
await perpExchange.closePosition(positionId);
```

### Position Management

```javascript
// Increase position size
await perpExchange.increasePosition(
    positionId,
    additionalCollateral,
    additionalSize
);

// Decrease position size
await perpExchange.decreasePosition(
    positionId,
    collateralToRemove,
    sizeToReduce
);
```

## 🔢 Mathematics & Calculations

### PnL Calculation

```javascript
// Long Position PnL
pnl = size * (currentPrice - avgPrice) / avgPrice

// Short Position PnL
pnl = size * (avgPrice - currentPrice) / avgPrice
```

### Liquidation Check

A position is liquidatable when:
```javascript
// For losing positions
remainingCollateral <= maintenanceMargin

// Where maintenanceMargin = size * maintenanceMarginBps / 10000
```

### Trading Fees

```javascript
fee = positionSize * tradingFeeBps / 10000
// Default: 0.1% = 10 bps
```

## 🔧 Contract Interactions

### PerpExchange Functions

```solidity
// Core trading functions
function openPosition(address indexToken, uint256 collateral, uint256 sizeDelta, bool isLong) external returns (uint256)
function closePosition(uint256 positionId) external
function increasePosition(uint256 positionId, uint256 collateralDelta, uint256 sizeDelta) external
function decreasePosition(uint256 positionId, uint256 collateralDelta, uint256 sizeDelta) external
function liquidatePosition(uint256 positionId) external

// View functions
function getPosition(uint256 positionId) external view returns (Position memory)
function validateLiquidation(uint256 positionId) external view returns (bool)
```

### Vault Functions

```solidity
// Collateral management
function deposit(address token, uint256 amount) external
function withdraw(address token, uint256 amount) external
function getBalance(address trader, address token) external view returns (uint256)
function getTradingBalance(address trader) external view returns (uint256)
```

### PriceFeed Functions

```solidity
// Oracle management
function getPrice(address token) external view returns (uint256)
function setPrice(address token, uint256 price) external
function isValidPrice(address token) external view returns (bool)
```

## 📊 Example Trading Scenarios

### Scenario 1: Profitable Long Position

```
1. Alice opens 10x long WETH/USD at $4,000
   - Collateral: 1000 USD
   - Position Size: 10,000 USD
   - Entry Price: $4,000

2. WETH price moves to $4,400 (+10%)
   - Position PnL: +$1,000 (100% on collateral)
   - Unrealized PnL: 10,000 * (4,400 - 4,000) / 4,000 = +$1,000

3. Alice closes position
   - Total Return: 1,000 + 1,000 - 10 (fee) = 1,990 USD
```

### Scenario 2: Liquidation

```
1. Bob opens 20x long WETH/USD at $4,000
   - Collateral: 500 USD
   - Position Size: 10,000 USD
   - Maintenance Margin: 50 USD (0.5% of size)

2. WETH price drops to $3,800 (-5%)
   - Position PnL: -$500
   - Remaining Collateral: 500 - 500 = 0 USD
   - Position gets liquidated as collateral < maintenance margin
```

## 🛡️ Security Features

### Oracle Security
- **Price Staleness Check**: Reject prices older than 10 minutes
- **Multiple Oracle Support**: Primary and fallback oracle capability
- **Owner-only Price Updates**: Authorized price posting in v1

### Position Safety
- **Liquidation Engine**: Automatic position closure when unsafe
- **Leverage Limits**: Maximum 50x leverage per market
- **Maintenance Margin**: Minimum collateral requirements

### Access Control
- **Owner Functions**: Market configuration, oracle management
- **User Functions**: Trading operations only
- **Vault Protection**: Isolated collateral management

## 🔄 Upgrade Roadmap

### Phase 1 (Current) - Core Trading
- ✅ Basic perpetual trading
- ✅ Long/short positions
- ✅ Oracle integration
- ✅ Simple liquidation

### Phase 2 - Advanced Features
- 🔄 Funding rate mechanism
- 🔄 Cross-margin trading
- 🔄 Stop loss/take profit orders
- 🔄 Multiple collateral tokens

### Phase 3 - Ecosystem
- 🔄 Chainlink oracle integration
- 🔄 Keeper network for liquidations
- 🔄 Insurance fund
- 🔄 Governance token integration

### Phase 4 - Scale
- 🔄 Multi-chain deployment
- 🔄 Advanced order types
- 🔄 Portfolio margin
- 🔄 Social trading features

## 📁 Project Structure

```
dewperp-perpetuals/
├── contracts/
│   └── perpetual/
│       ├── core/
│       │   ├── PerpExchange.sol
│       │   └── Vault.sol
│       ├── interfaces/
│       │   ├── IPerpExchange.sol
│       │   ├── IVault.sol
│       │   └── IPriceFeed.sol
│       ├── libraries/
│       │   └── PerpMath.sol
│       └── oracle/
│           └── PriceFeed.sol
├── scripts/
│   ├── deployPerp.js
│   └── updatePerpPrice.js
├── perp-deployments.json
└── README.md
```

## ⚠️ Risk Warnings

1. **High Leverage Risk**: Leveraged trading can result in significant losses
2. **Liquidation Risk**: Positions can be liquidated if margin falls below maintenance
3. **Oracle Risk**: Price feed delays or errors can affect trading
4. **Smart Contract Risk**: Protocol is in early development
5. **Market Risk**: Cryptocurrency markets are highly volatile

## 🧪 Testing

```bash
# Run all tests
npx hardhat test

# Test specific functionality
npx hardhat test --grep "perpetual"
```

## 📊 Analytics & Monitoring

### Key Metrics to Track
- Total Value Locked (TVL)
- Open Interest (Long vs Short)
- Trading Volume
- Liquidation Rate
- Fee Revenue

### Events for Analytics
- `PositionOpened`
- `PositionClosed`
- `PositionLiquidated`
- `PositionIncreased`
- `PositionDecreased`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Add comprehensive tests
5. Update documentation
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**⚠️ DISCLAIMER**: This software is experimental and for educational purposes. Trading perpetual futures involves significant risk. Use at your own risk.**

**Built with ⚡ for the Paxeer Network ecosystem**