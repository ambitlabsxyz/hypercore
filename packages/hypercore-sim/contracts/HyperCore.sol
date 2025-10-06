// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { DoubleEndedQueue } from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import { Heap } from "@openzeppelin/contracts/utils/structs/Heap.sol";
import { CoreReaderLib } from "@ambitlabs/hypercore/contracts/CoreReaderLib.sol";
import { CoreWriterLib } from "@ambitlabs/hypercore/contracts/CoreWriterLib.sol";
import { SpotERC20 } from "./SpotERC20.sol";
import { SerializationLib } from "./SerializationLib.sol";

uint64 constant KNOWN_TOKEN_USDC = 0;
uint64 constant KNOWN_TOKEN_HYPE = 150;

contract HyperCore {
  using Address for address payable;
  using SafeCast for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;
  using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;
  using Heap for Heap.Uint256Heap;

  mapping(uint64 token => CoreReaderLib.TokenInfo) private _tokens;

  struct WithdrawRequest {
    address account;
    uint64 amount;
    uint32 lockedUntilTimestamp;
  }

  struct Account {
    bool created;
    uint64 perp;
    mapping(uint64 => uint64) spot;
    mapping(address vault => CoreReaderLib.UserVaultEquity) vaultEquity;
    uint64 staking;
    mapping(address validator => CoreReaderLib.Delegation) delegations;
  }

  mapping(address account => Account) private _accounts;

  mapping(address vault => uint64) private _vaultEquity;

  DoubleEndedQueue.Bytes32Deque private _withdrawQueue;

  EnumerableSet.AddressSet private _validators;

  constructor() {
    registerTokenInfo(
      KNOWN_TOKEN_HYPE,
      CoreReaderLib.TokenInfo({
        name: "HYPE",
        spots: new uint64[](0),
        deployerTradingFeeShare: 0,
        deployer: address(0),
        evmContract: address(0),
        szDecimals: 2,
        weiDecimals: 8,
        evmExtraWeiDecimals: 0
      })
    );
  }

  receive() external payable {}

  modifier whenAccountCreated(address sender) {
    if (_accounts[sender].created == false) {
      return;
    }
    _;
  }

  function registerTokenInfo(uint64 index, CoreReaderLib.TokenInfo memory tokenInfo) public {
    require(bytes(_tokens[index].name).length == 0);
    require(tokenInfo.evmContract == address(0));

    _tokens[index] = tokenInfo;
  }

  function registerValidator(address validator) public {
    _validators.add(validator);
  }

  function deploySpotERC20(uint64 index) external returns (SpotERC20 spot) {
    require(_tokens[index].evmContract == address(0));

    spot = new SpotERC20(index, _tokens[index]);

    _tokens[index].evmContract = address(spot);
  }

  /// @dev account creation can be forced when there isnt a reliance on testing that workflow.
  function forceAccountCreation(address account) public {
    _accounts[account].created = true;
  }

  function forceSpot(address account, uint64 token, uint64 _wei) public payable {
    forceAccountCreation(account);
    _accounts[account].spot[token] = _wei;
  }

  function forcePerp(address account, uint64 usd) public payable {
    forceAccountCreation(account);
    _accounts[account].perp = usd;
  }

  function forceStaking(address account, uint64 _wei) public payable {
    forceAccountCreation(account);
    _accounts[account].staking = _wei;
  }

  function forceDelegation(address account, address validator, uint64 amount, uint64 lockedUntilTimestamp) public {
    forceAccountCreation(account);
    _accounts[account].delegations[validator] = CoreReaderLib.Delegation({
      validator: validator,
      amount: amount,
      lockedUntilTimestamp: lockedUntilTimestamp
    });
  }

  function forceVaultEquity(address account, address vault, uint64 usd, uint64 lockedUntilTimestamp) public payable {
    forceAccountCreation(account);

    _vaultEquity[vault] -= _accounts[account].vaultEquity[vault].equity;
    _vaultEquity[vault] += usd;

    _accounts[account].vaultEquity[vault].equity = usd;
    _accounts[account].vaultEquity[vault].lockedUntilTimestamp = lockedUntilTimestamp > 0
      ? lockedUntilTimestamp
      : uint64((block.timestamp + 3600) * 1000);
  }

  function tokenExists(uint64 token) private view returns (bool) {
    return bytes(_tokens[token].name).length > 0;
  }

  /// @dev unstaking takes 7 days and after which it will automatically appear in the users
  /// spot balance so we need to check this at the end of each operation to simulate that.
  function flushCWithdrawQueue() public {
    while (_withdrawQueue.length() > 0) {
      WithdrawRequest memory request = SerializationLib.deserializeWithdrawRequest(_withdrawQueue.front());

      if (request.lockedUntilTimestamp > block.timestamp) {
        break;
      }

      _withdrawQueue.popFront();

      _accounts[request.account].spot[KNOWN_TOKEN_HYPE] += request.amount;
    }
  }

  function executeTokenTransfer(
    address,
    uint64 token,
    address from,
    uint256 value
  ) public payable whenAccountCreated(from) {
    require(tokenExists(token));
    _accounts[from].spot[token] += toWei(value, _tokens[token].evmExtraWeiDecimals);
  }

  function executeNativeTransfer(address, address from, uint256 value) public payable whenAccountCreated(from) {
    _accounts[from].spot[KNOWN_TOKEN_HYPE] += (value / 1e10).toUint64();
  }

  function executeRawAction(address sender, uint24 kind, bytes calldata data) public payable {
    if (kind == CoreWriterLib.CORE_WRITER_ACTION_LIMIT_ORDER) {
      //executeLimitOrder(sender, abi.decode(data, (CoreWriterLib.LimitOrderAction)));
      return;
    }

    if (kind == CoreWriterLib.CORE_WRITER_ACTION_VAULT_TRANSFER) {
      executeVaultTransfer(sender, abi.decode(data, (CoreWriterLib.VaultTransferAction)));
      return;
    }

    if (kind == CoreWriterLib.CORE_WRITER_ACTION_TOKEN_DELEGATE) {
      executeTokenDelegate(sender, abi.decode(data, (CoreWriterLib.TokenDelegateAction)));
      return;
    }

    if (kind == CoreWriterLib.CORE_WRITER_ACTION_STAKING_DEPOSIT) {
      executeStakingDeposit(sender, abi.decode(data, (CoreWriterLib.StakingDepositAction)));
      return;
    }

    if (kind == CoreWriterLib.CORE_WRITER_ACTION_STAKING_WITHDRAW) {
      executeStakingWithdraw(sender, abi.decode(data, (CoreWriterLib.StakingWithdrawAction)));
      return;
    }

    if (kind == CoreWriterLib.CORE_WRITER_ACTION_SPOT_SEND) {
      executeSpotSend(sender, abi.decode(data, (CoreWriterLib.SpotSendAction)));
      return;
    }

    if (kind == CoreWriterLib.CORE_WRITER_ACTION_USD_CLASS_TRANSFER) {
      executeUsdClassTransfer(sender, abi.decode(data, (CoreWriterLib.UsdClassTransferAction)));
      return;
    }

    if (kind == CoreWriterLib.CORE_WRITER_ACTION_SEND_ASSET) {
      executeSendAsset(sender, abi.decode(data, (CoreWriterLib.SendAssetAction)));
      return;
    }
  }

  function executeSendAsset(
    address sender,
    CoreWriterLib.SendAssetAction memory action
  ) private whenAccountCreated(sender) {
    // for now we just implement sendAsset as a spotSend and a usdClassTransfer as two separate actions

    executeSpotSend(sender, CoreWriterLib.SpotSendAction(action.destination, action.token, action._wei));

    uint256 usd = scale(action._wei, _tokens[action.token].weiDecimals, 6);

    executeUsdClassTransfer(action.destination, CoreWriterLib.UsdClassTransferAction(usd.toUint64(), true));
  }

  function executeSpotSend(
    address sender,
    CoreWriterLib.SpotSendAction memory action
  ) private whenAccountCreated(sender) {
    if (action._wei > _accounts[sender].spot[action.token]) {
      return;
    }

    _accounts[sender].spot[action.token] -= action._wei;

    address systemAddress = action.token == 150
      ? 0x2222222222222222222222222222222222222222
      : address(uint160(address(0x2000000000000000000000000000000000000000)) + action.token);

    if (action.destination == systemAddress) {
      if (action.token == KNOWN_TOKEN_HYPE) {
        payable(sender).sendValue(action._wei * 1e10);
        return;
      }
      SpotERC20(_tokens[action.token].evmContract).transferFrom(
        action.destination,
        sender,
        fromWei(action._wei, _tokens[action.token].evmExtraWeiDecimals)
      );
      return;
    }

    _accounts[action.destination].spot[action.token] += action._wei;

    if (_accounts[action.destination].created == false) {
      // TODO: this should deduct some HYPE balance from the sender in order to create the destination
      _accounts[action.destination].created = true;
    }
  }

  function executeUsdClassTransfer(
    address sender,
    CoreWriterLib.UsdClassTransferAction memory action
  ) private whenAccountCreated(sender) {
    uint64 _wei = scale(action.ntl, 6, _tokens[KNOWN_TOKEN_USDC].weiDecimals).toUint64();

    if (action.toPerp) {
      if (_wei <= _accounts[sender].spot[KNOWN_TOKEN_USDC]) {
        _accounts[sender].perp += action.ntl;
        _accounts[sender].spot[KNOWN_TOKEN_USDC] -= _wei;
      }
    } else {
      if (action.ntl <= _accounts[sender].perp) {
        _accounts[sender].perp -= action.ntl;
        _accounts[sender].spot[KNOWN_TOKEN_USDC] += _wei;
      }
    }
  }

  function executeVaultTransfer(
    address sender,
    CoreWriterLib.VaultTransferAction memory action
  ) private whenAccountCreated(sender) {
    if (action.isDeposit) {
      if (action.usd <= _accounts[sender].perp) {
        _accounts[sender].vaultEquity[action.vault].equity += action.usd;
        _accounts[sender].vaultEquity[action.vault].lockedUntilTimestamp = uint64((block.timestamp + 3600) * 1000);
        _accounts[sender].perp -= action.usd;
        _vaultEquity[action.vault] += action.usd;
      }
    } else {
      CoreReaderLib.UserVaultEquity storage userVaultEquity = _accounts[sender].vaultEquity[action.vault];

      // a zero amount means withdraw the entire amount
      action.usd = action.usd == 0 ? userVaultEquity.equity : action.usd;

      // the vaults have a minimum withdraw of 1 / 100,000,000
      if (action.usd < _vaultEquity[action.vault] / 1e8) {
        return;
      }

      if (action.usd <= userVaultEquity.equity && userVaultEquity.lockedUntilTimestamp / 1000 <= block.timestamp) {
        userVaultEquity.equity -= action.usd;
        _accounts[sender].perp += action.usd;
      }
    }
  }

  function executeStakingDeposit(
    address sender,
    CoreWriterLib.StakingDepositAction memory action
  ) private whenAccountCreated(sender) {
    if (action._wei <= _accounts[sender].spot[KNOWN_TOKEN_HYPE]) {
      _accounts[sender].spot[KNOWN_TOKEN_HYPE] -= action._wei;
      _accounts[sender].staking += action._wei;
    }
  }

  function executeStakingWithdraw(
    address sender,
    CoreWriterLib.StakingWithdrawAction memory action
  ) private whenAccountCreated(sender) {
    if (action._wei <= _accounts[sender].staking) {
      _accounts[sender].staking -= action._wei;

      WithdrawRequest memory withrawRequest = WithdrawRequest({
        account: sender,
        amount: action._wei,
        lockedUntilTimestamp: uint32(block.timestamp + 7 days)
      });

      _withdrawQueue.pushBack(SerializationLib.serializeWithdrawRequest(withrawRequest));
    }
  }

  function executeTokenDelegate(address sender, CoreWriterLib.TokenDelegateAction memory action) private {
    require(_validators.contains(action.validator));

    if (action.isUndelegate) {
      CoreReaderLib.Delegation storage delegation = _accounts[sender].delegations[action.validator];
      if (action._wei <= delegation.amount && block.timestamp * 1000 > delegation.lockedUntilTimestamp) {
        _accounts[sender].staking += action._wei;
        delegation.amount -= action._wei;
      }
    } else {
      if (action._wei <= _accounts[sender].staking) {
        _accounts[sender].staking -= action._wei;
        _accounts[sender].delegations[action.validator].amount += action._wei;
        _accounts[sender].delegations[action.validator].lockedUntilTimestamp = ((block.timestamp + 84600) * 1000)
          .toUint64();
      }
    }
  }

  function readTokenInfo(uint32 token) public view returns (CoreReaderLib.TokenInfo memory) {
    require(tokenExists(token));
    return _tokens[token];
  }

  function readSpotBalance(address account, uint64 token) public view returns (CoreReaderLib.SpotBalance memory) {
    require(tokenExists(token));
    return CoreReaderLib.SpotBalance({ total: _accounts[account].spot[token], entryNtl: 0, hold: 0 });
  }

  function readWithdrawable(address account) public view returns (CoreReaderLib.Withdrawable memory) {
    return CoreReaderLib.Withdrawable({ withdrawable: _accounts[account].perp });
  }

  function readUserVaultEquity(address user, address vault) public view returns (CoreReaderLib.UserVaultEquity memory) {
    return _accounts[user].vaultEquity[vault];
  }

  function readDelegation(
    address user,
    address validator
  ) public view returns (CoreReaderLib.Delegation memory delegation) {
    delegation.validator = validator;
    delegation.amount = _accounts[user].delegations[validator].amount;
    delegation.lockedUntilTimestamp = _accounts[user].delegations[validator].lockedUntilTimestamp;
  }

  function readDelegations(address user) public view returns (CoreReaderLib.Delegation[] memory userDelegations) {
    address[] memory validators = _validators.values();

    userDelegations = new CoreReaderLib.Delegation[](validators.length);
    for (uint256 i; i < userDelegations.length; i++) {
      userDelegations[i].validator = validators[i];

      CoreReaderLib.Delegation memory delegation = _accounts[user].delegations[validators[i]];
      userDelegations[i].amount = delegation.amount;
      userDelegations[i].lockedUntilTimestamp = delegation.lockedUntilTimestamp;
    }
  }

  function readDelegatorSummary(address user) public view returns (CoreReaderLib.DelegatorSummary memory summary) {
    address[] memory validators = _validators.values();

    for (uint256 i; i < validators.length; i++) {
      CoreReaderLib.Delegation memory delegation = _accounts[user].delegations[validators[i]];
      summary.delegated += delegation.amount;
    }

    summary.undelegated = _accounts[user].staking;

    for (uint256 i; i < _withdrawQueue.length(); i++) {
      WithdrawRequest memory request = SerializationLib.deserializeWithdrawRequest(_withdrawQueue.at(i));
      if (request.account == user) {
        summary.nPendingWithdrawals++;
        summary.totalPendingWithdrawal += request.amount;
      }
    }
  }

  function readPosition(address user, uint16 perp) public view returns (CoreReaderLib.Position memory) {
    // TODO
  }

  function toWei(uint256 amount, int8 evmExtraWeiDecimals) private pure returns (uint64) {
    uint256 _wei = evmExtraWeiDecimals == 0 ? amount : evmExtraWeiDecimals > 0
      ? amount / 10 ** uint8(evmExtraWeiDecimals)
      : amount * 10 ** uint8(-evmExtraWeiDecimals);

    return _wei.toUint64();
  }

  function fromWei(uint64 _wei, int8 evmExtraWeiDecimals) private pure returns (uint256) {
    return
      evmExtraWeiDecimals == 0 ? _wei : evmExtraWeiDecimals > 0
        ? _wei * 10 ** uint8(evmExtraWeiDecimals)
        : _wei / 10 ** uint8(-evmExtraWeiDecimals);
  }

  function scale(uint256 amount, uint8 from, uint8 to) internal pure returns (uint256) {
    if (from < to) {
      return amount * 10 ** uint256(to - from);
    }
    if (from > to) {
      return amount / 10 ** uint256(from - to);
    }
    return amount;
  }
}
