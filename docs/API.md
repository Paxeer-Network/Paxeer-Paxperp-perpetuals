# ⚡ DewPerp API Documentation

## Core Contracts API

### PerpExchange

The main trading contract for perpetual futures.

#### Structs

##### Position
```solidity
struct Position {
    uint256 id;               // Unique position identifier
    address trader;           // Position owner
    address indexToken;       // Underlying asset (e.g., WETH)
    bool isLong;             // Long (true) or Short (false)
    uint256 size;            // Position size in USD (1e30 precision)
    uint256 collateral;      // Collateral amount (1e30 precision)
    uint256 avgPrice;        // Average entry price (1e30 precision)
    uint256 entryFundingRate; // Entry funding rate
    uint256 reserveAmount;    // Reserved amount (future use)
    uint256 realisedPnl;     // Realized PnL
    uint256 lastUpdatedBlock; // Last update block number
}
```

#### Functions

##### `openPosition(address indexToken, uint256 collateral, uint256 sizeDelta, bool isLong) → uint256 positionId`

Opens a new perpetual position.

**Parameters:**
- `indexToken`: Address of the underlying asset (e.g., WETH)
- `collateral`: Collateral amount in USD (1e30 precision)
- `sizeDelta`: Position size in USD (1e30 precision)
- `isLong`: `true` for long, `false` for short

**Returns:**
- `positionId`: Unique identifier for the position

**Requirements:**
- Market must be active
- Collateral and size must be > 0
- Leverage must not exceed maximum allowed
- Sufficient trading balance in vault

**Events:**
- `PositionOpened(uint256 indexed positionId, address indexed trader, address indexed indexToken, bool isLong, uint256 size, uint256 collateral, uint256 avgPrice)`

**Example:**
```javascript
const collateral = ethers.parseEther("1000");  // 1000 USD (1e30)
const size = ethers.parseEther("10000");       // 10000 USD (1e30) = 10x leverage
const isLong = true;

const tx = await perpExchange.openPosition(
    WETH_ADDRESS,
    collateral,
    size,
    isLong
);
const receipt = await tx.wait();
const positionId = receipt.logs[0].args.positionId;
```

##### `closePosition(uint256 positionId)`

Closes an existing position completely.

**Parameters:**
- `positionId`: ID of the position to close

**Requirements:**
- Position must exist and belong to caller
- Position size must be > 0

**Events:**
- `PositionClosed(uint256 indexed positionId, address indexed trader, uint256 size, uint256 collateral, uint256 avgPrice, int256 pnl, uint256 fee)`

##### `increasePosition(uint256 positionId, uint256 collateralDelta, uint256 sizeDelta)`

Increases position size and/or adds collateral.

**Parameters:**
- `positionId`: ID of the position
- `collateralDelta`: Additional collateral to add
- `sizeDelta`: Additional size to add

**Events:**
- `PositionIncreased(uint256 indexed positionId, uint256 collateralDelta, uint256 sizeDelta, uint256 price, uint256 fee)`

##### `decreasePosition(uint256 positionId, uint256 collateralDelta, uint256 sizeDelta)`

Decreases position size and/or removes collateral.

**Parameters:**
- `positionId`: ID of the position
- `collateralDelta`: Collateral amount to remove
- `sizeDelta`: Size amount to remove

**Events:**
- `PositionDecreased(uint256 indexed positionId, uint256 collateralDelta, uint256 sizeDelta, uint256 price, uint256 fee)`

##### `liquidatePosition(uint256 positionId)`

Liquidates an unsafe position.

**Parameters:**
- `positionId`: ID of the position to liquidate

**Requirements:**
- Position must be liquidatable (validated by `validateLiquidation`)

**Events:**
- `PositionLiquidated(uint256 indexed positionId, address indexed trader, address indexed liquidator, uint256 size, uint256 collateral, int256 pnl, uint256 fee)`

#### View Functions

##### `getPosition(uint256 positionId) → Position`

Returns complete position information.

##### `validateLiquidation(uint256 positionId) → bool`

Checks if a position can be liquidated.

**Returns:**
- `true` if position is liquidatable, `false` otherwise

**Liquidation Conditions:**
- Position loss >= collateral, OR
- Remaining collateral <= maintenance margin

##### `getPositionKey(address trader, address indexToken, bool isLong) → bytes32`

Generates a unique key for position lookup.

---

### Vault

Manages user collateral and trading balances.

#### Functions

##### `deposit(address token, uint256 amount)`

Deposits collateral tokens into the vault.

**Parameters:**
- `token`: Address of the token to deposit
- `amount`: Amount to deposit

**Requirements:**
- Token must be whitelisted
- Amount must be > 0
- User must have sufficient token balance and approval

**Events:**
- `Deposit(address indexed user, address indexed token, uint256 amount)`

##### `withdraw(address token, uint256 amount)`

Withdraws collateral tokens from the vault.

**Parameters:**
- `token`: Address of the token to withdraw
- `amount`: Amount to withdraw

**Requirements:**
- User must have sufficient balance in vault

**Events:**
- `Withdraw(address indexed user, address indexed token, uint256 amount)`

##### `transferToTrading(address trader, uint256 amount)`

Moves funds to trading balance (owner only).

##### `transferFromTrading(address trader, uint256 amount)`

Moves funds from trading balance (owner only).

#### View Functions

##### `getBalance(address trader, address token) → uint256`

Returns user's token balance in vault.

##### `getTradingBalance(address trader) → uint256`

Returns user's trading balance (in USD, 1e30 precision).

##### `isWhitelisted(address token) → bool`

Checks if a token is whitelisted for deposits.

---

### PriceFeed

Oracle price feed aggregator.

#### Functions

##### `setPrice(address token, uint256 price)`

Updates the price for a token (oracle only).

**Parameters:**
- `token`: Token address
- `price`: Price with 8 decimals (e.g., 423000000000 for $4230.00)

**Requirements:**
- Caller must be authorized oracle or owner
- Price must be > 0

**Events:**
- `PriceUpdate(address indexed token, uint256 price, uint256 timestamp)`

##### `addOracle(address token, address oracle)`

Adds an oracle for a token (owner only).

##### `removeOracle(address token)`

Removes the oracle for a token (owner only).

#### View Functions

##### `getPrice(address token) → uint256`

Returns the latest price for a token.

**Returns:**
- Price with 8 decimals

##### `getLatestPrice(address token) → (uint256 price, uint256 timestamp)`

Returns price and timestamp.

##### `isValidPrice(address token) → bool`

Checks if the price is valid (not stale).

**Returns:**
- `true` if price is less than 10 minutes old

##### `getPriceDecimals() → uint8`

Returns the price decimals (always 8).

---

## Integration Examples

### Opening a Position

```javascript
class PerpTrader {
    constructor(perpExchangeAddress, vaultAddress, provider) {
        this.perp = new ethers.Contract(perpExchangeAddress, perpABI, provider);
        this.vault = new ethers.Contract(vaultAddress, vaultABI, provider);
        this.signer = provider.getSigner();
    }
    
    async openLongPosition(indexToken, collateralUsd, leverage) {
        const collateral = ethers.parseEther(collateralUsd.toString());
        const size = collateral.mul(leverage);
        
        // Check trading balance
        const tradingBalance = await this.vault.getTradingBalance(this.signer.address);
        if (tradingBalance.lt(collateral)) {
            throw new Error('Insufficient trading balance');
        }
        
        // Open position
        const tx = await this.perp.openPosition(
            indexToken,
            collateral,
            size,
            true // isLong
        );
        
        return await tx.wait();
    }
    
    async closePosition(positionId) {
        const tx = await this.perp.closePosition(positionId);
        return await tx.wait();
    }
    
    async getPositionPnL(positionId, currentPrice) {
        const position = await this.perp.getPosition(positionId);
        if (position.size.eq(0)) return 0;
        
        const pricePrecision = ethers.BigNumber.from('1000000000000000000000000000000'); // 1e30
        const avgPrice = position.avgPrice;
        const size = position.size;
        
        let pnl;
        if (position.isLong) {
            // Long PnL = size * (currentPrice - avgPrice) / avgPrice
            if (currentPrice.gte(avgPrice)) {
                pnl = size.mul(currentPrice.sub(avgPrice)).div(avgPrice);
            } else {
                pnl = size.mul(avgPrice.sub(currentPrice)).div(avgPrice).mul(-1);
            }
        } else {
            // Short PnL = size * (avgPrice - currentPrice) / avgPrice
            if (avgPrice.gte(currentPrice)) {
                pnl = size.mul(avgPrice.sub(currentPrice)).div(avgPrice);
            } else {
                pnl = size.mul(currentPrice.sub(avgPrice)).div(avgPrice).mul(-1);
            }
        }
        
        return pnl;
    }
}
```

### Price Monitoring

```javascript
class PriceMonitor {
    constructor(priceFeedAddress, provider) {
        this.priceFeed = new ethers.Contract(priceFeedAddress, priceFeedABI, provider);
    }
    
    async getCurrentPrice(token) {
        const price = await this.priceFeed.getPrice(token);
        return price;
    }
    
    async isValidPrice(token) {
        return await this.priceFeed.isValidPrice(token);
    }
    
    // Monitor price updates
    startPriceMonitoring(token, callback) {
        this.priceFeed.on('PriceUpdate', (tokenAddr, price, timestamp) => {
            if (tokenAddr.toLowerCase() === token.toLowerCase()) {
                callback({
                    token: tokenAddr,
                    price: price.toString(),
                    timestamp: timestamp.toNumber(),
                    priceFormatted: ethers.utils.formatUnits(price, 8)
                });
            }
        });
    }
}
```

### Liquidation Bot

```javascript
class LiquidationBot {
    constructor(perpExchangeAddress, provider) {
        this.perp = new ethers.Contract(perpExchangeAddress, perpABI, provider);
        this.signer = provider.getSigner();
    }
    
    async checkLiquidations(positionIds) {
        const liquidatablePositions = [];
        
        for (const positionId of positionIds) {
            try {
                const isLiquidatable = await this.perp.validateLiquidation(positionId);
                if (isLiquidatable) {
                    liquidatablePositions.push(positionId);
                }
            } catch (error) {
                console.log(`Error checking position ${positionId}:`, error.message);
            }
        }
        
        return liquidatablePositions;
    }
    
    async liquidatePosition(positionId) {
        try {
            const tx = await this.perp.liquidatePosition(positionId);
            const receipt = await tx.wait();
            console.log(`Liquidated position ${positionId}. Tx: ${receipt.transactionHash}`);
            return receipt;
        } catch (error) {
            console.log(`Failed to liquidate position ${positionId}:`, error.message);
            throw error;
        }
    }
}
```

### Analytics Dashboard

```javascript
class PerpAnalytics {
    constructor(perpExchangeAddress, provider) {
        this.perp = new ethers.Contract(perpExchangeAddress, perpABI, provider);
        this.provider = provider;
    }
    
    async getPositionEvents(fromBlock = 0) {
        const events = await this.perp.queryFilter('*', fromBlock);
        
        const positions = {
            opened: [],
            closed: [],
            liquidated: [],
            increased: [],
            decreased: []
        };
        
        for (const event of events) {
            switch (event.event) {
                case 'PositionOpened':
                    positions.opened.push(this.parsePositionEvent(event));
                    break;
                case 'PositionClosed':
                    positions.closed.push(this.parsePositionEvent(event));
                    break;
                case 'PositionLiquidated':
                    positions.liquidated.push(this.parsePositionEvent(event));
                    break;
                case 'PositionIncreased':
                    positions.increased.push(this.parsePositionEvent(event));
                    break;
                case 'PositionDecreased':
                    positions.decreased.push(this.parsePositionEvent(event));
                    break;
            }
        }
        
        return positions;
    }
    
    parsePositionEvent(event) {
        return {
            transactionHash: event.transactionHash,
            blockNumber: event.blockNumber,
            event: event.event,
            args: event.args,
            timestamp: null // Would need to fetch block timestamp
        };
    }
    
    async calculateMetrics(positions) {
        const metrics = {
            totalVolume: ethers.BigNumber.from(0),
            totalFees: ethers.BigNumber.from(0),
            liquidationRate: 0,
            avgPositionSize: ethers.BigNumber.from(0)
        };
        
        // Calculate total volume
        for (const pos of positions.opened) {
            metrics.totalVolume = metrics.totalVolume.add(pos.args.size);
        }
        
        // Calculate liquidation rate
        const totalPositions = positions.opened.length;
        const liquidatedPositions = positions.liquidated.length;
        metrics.liquidationRate = totalPositions > 0 ? (liquidatedPositions / totalPositions) * 100 : 0;
        
        // Calculate average position size
        if (totalPositions > 0) {
            metrics.avgPositionSize = metrics.totalVolume.div(totalPositions);
        }
        
        return metrics;
    }
}
```

## Error Handling

### Common Errors

| Error | Description | Solution |
|-------|-------------|----------|
| `OwnerOnly` | Function restricted to owner | Call from owner address |
| `NotOwner` | Position doesn't belong to caller | Use correct position owner |
| `MarketInactive` | Trading market is disabled | Wait for market activation |
| `BadParams` | Invalid function parameters | Check parameter values |
| `LeverageTooHigh` | Leverage exceeds maximum | Reduce position size or add collateral |
| `LeverageTooLow` | Position size too small vs collateral | Increase position size |
| `NoPosition` | Position doesn't exist or size is 0 | Check position ID |
| `NotLiquidatable` | Position is safe from liquidation | Wait for price movement |
| `InsufficientBalance` | Not enough vault balance | Deposit more collateral |
| `InsufficientTradingBalance` | Not enough trading balance | Transfer from vault balance |
| `NoPrice` | Oracle price not available | Wait for price update |
| `TokenNotAllowed` | Token not whitelisted in vault | Use whitelisted tokens |

### Error Handling Example

```javascript
async function safeOpenPosition(indexToken, collateral, size, isLong) {
    try {
        const tx = await perpExchange.openPosition(indexToken, collateral, size, isLong);
        return await tx.wait();
    } catch (error) {
        if (error.message.includes('LeverageTooHigh')) {
            throw new Error('Leverage too high. Reduce position size or add more collateral.');
        } else if (error.message.includes('MarketInactive')) {
            throw new Error('Market is currently inactive. Please try again later.');
        } else if (error.message.includes('InsufficientTradingBalance')) {
            throw new Error('Insufficient trading balance. Please deposit more collateral.');
        } else {
            throw new Error(`Failed to open position: ${error.message}`);
        }
    }
}
```

## Events Reference

### Position Events

All position events include these common fields:
- `positionId`: Unique position identifier
- `trader`: Position owner address
- Block number and transaction hash

#### PositionOpened
```solidity
event PositionOpened(
    uint256 indexed positionId,
    address indexed trader,
    address indexed indexToken,
    bool isLong,
    uint256 size,
    uint256 collateral,
    uint256 avgPrice
);
```

#### PositionClosed
```solidity
event PositionClosed(
    uint256 indexed positionId,
    address indexed trader,
    uint256 size,
    uint256 collateral,
    uint256 avgPrice,
    int256 pnl,
    uint256 fee
);
```

#### PositionLiquidated
```solidity
event PositionLiquidated(
    uint256 indexed positionId,
    address indexed trader,
    address indexed liquidator,
    uint256 size,
    uint256 collateral,
    int256 pnl,
    uint256 fee
);
```
