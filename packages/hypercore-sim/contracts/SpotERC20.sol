// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { CoreReaderLib } from "@ambitlabs/hypercore/contracts/CoreReaderLib.sol";
import { HyperCoreWrite } from "./HyperCoreWrite.sol";
import { KNOWN_TOKEN_HYPE } from "./HyperCore.sol";

contract SpotERC20 {
  error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

  uint64 _index;

  CoreReaderLib.TokenInfo _token;

  uint256 private _totalSupply;

  address private _systemAddress;

  mapping(address account => uint256) private _balances;

  constructor(uint64 index, CoreReaderLib.TokenInfo memory token) {
    _index = index;
    _token = token;

    _systemAddress = index == KNOWN_TOKEN_HYPE
      ? 0x2222222222222222222222222222222222222222
      : address(uint160(address(0x2000000000000000000000000000000000000000)) + index);
  }

  function name() public view returns (string memory) {
    return _token.name;
  }

  function symbol() public view returns (string memory) {
    return _token.name;
  }

  function decimals() public view returns (uint8) {
    return uint8(int8(_token.weiDecimals) + _token.evmExtraWeiDecimals);
  }

  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
  }

  function transfer(address to, uint256 value) external returns (bool) {
    return transferFrom(msg.sender, to, value);
  }

  function allowance(address owner, address spender) external pure returns (uint256) {
    return type(uint256).max;
  }

  function approve(address spender, uint256 value) external pure returns (bool) {
    return true;
  }

  function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
    require(_balances[from] >= value, ERC20InsufficientBalance(from, _balances[from], value));

    _balances[from] -= value;
    _balances[to] += value;

    if (to == _systemAddress) {
      HyperCoreWrite(0x3333333333333333333333333333333333333333).tokenTransferCallback(_index, from, value);
    }

    return true;
  }

  function mint(address account, uint256 amount) public {
    _balances[account] += amount;
    _totalSupply += amount;
  }

  function burn(address account, uint256 amount) public {
    _balances[account] -= amount;
    _totalSupply -= amount;
  }
}
