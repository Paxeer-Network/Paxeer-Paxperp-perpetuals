// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../interfaces/IVault.sol";
import "../../interfaces/IERC20.sol";

contract Vault is IVault {
    address public owner;

    mapping(address => bool) public whitelisted;
    mapping(address => mapping(address => uint256)) public balances; // user => token => amount
    mapping(address => uint256) public tradingBalances; // user => usd equivalent (for simplicity we use a single settlement token in v1)

    modifier onlyOwner() { require(msg.sender == owner, "OwnerOnly"); _; }

    constructor() { owner = msg.sender; }

    function whitelistToken(address _token, bool _whitelist) external onlyOwner {
        whitelisted[_token] = _whitelist;
    }

    function isWhitelisted(address _token) external view returns (bool) { return whitelisted[_token]; }

    function deposit(address _token, uint256 _amount) external {
        require(whitelisted[_token], "TokenNotAllowed");
        require(_amount > 0, "ZeroAmount");
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender][_token] += _amount;
        emit Deposit(msg.sender, _token, _amount);
    }

    function depositETH() external payable {
        revert("ETHNotSupportedInV1");
    }

    function withdraw(address _token, uint256 _amount) external {
        require(balances[msg.sender][_token] >= _amount, "InsufficientBalance");
        balances[msg.sender][_token] -= _amount;
        IERC20(_token).transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _token, _amount);
    }

    function transferToTrading(address _trader, uint256 _amount) external onlyOwner {
        tradingBalances[_trader] += _amount;
        emit TransferToTrading(_trader, _amount);
    }

    function transferFromTrading(address _trader, uint256 _amount) external onlyOwner {
        require(tradingBalances[_trader] >= _amount, "InsufficientTradingBalance");
        tradingBalances[_trader] -= _amount;
        emit TransferFromTrading(_trader, _amount);
    }

    function getBalance(address _trader, address _token) external view returns (uint256) {
        return balances[_trader][_token];
    }

    function getTradingBalance(address _trader) external view returns (uint256) {
        return tradingBalances[_trader];
    }

    function transferOwnership(address _owner) external onlyOwner { owner = _owner; }
}
