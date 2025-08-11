// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IVault {
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event TransferToTrading(address indexed user, uint256 amount);
    event TransferFromTrading(address indexed user, uint256 amount);

    function deposit(address _token, uint256 _amount) external;
    function depositETH() external payable;
    function withdraw(address _token, uint256 _amount) external;
    
    function transferToTrading(address _trader, uint256 _amount) external;
    function transferFromTrading(address _trader, uint256 _amount) external;
    
    function getBalance(address _trader, address _token) external view returns (uint256);
    function getTradingBalance(address _trader) external view returns (uint256);
    
    function whitelistToken(address _token, bool _whitelist) external;
    function isWhitelisted(address _token) external view returns (bool);
}
