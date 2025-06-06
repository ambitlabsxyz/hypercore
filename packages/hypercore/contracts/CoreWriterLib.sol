// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { CoreWriter } from "./CoreWriter.sol";

library CoreWriterLib {
  using SafeCast for uint256;

  address public constant CORE_WRITER = 0x3333333333333333333333333333333333333333;

  uint8 public constant CORE_WRITER_VERSION_1 = 1;

  uint24 public constant CORE_WRITER_ACTION_LIMIT_ORDER = 1;
  uint24 public constant CORE_WRITER_ACTION_VAULT_TRANSFER = 2;
  uint24 public constant CORE_WRITER_ACTION_TOKEN_DELEGATE = 3;
  uint24 public constant CORE_WRITER_ACTION_STAKING_DEPOSIT = 4;
  uint24 public constant CORE_WRITER_ACTION_STAKING_WITHDRAW = 5;
  uint24 public constant CORE_WRITER_ACTION_SPOT_SEND = 6;
  uint24 public constant CORE_WRITER_ACTION_USD_CLASS_TRANSFER = 7;

  uint8 public constant LIMIT_ORDER_TIF_ALO = 1;
  uint8 public constant LIMIT_ORDER_TIF_GTC = 2;
  uint8 public constant LIMIT_ORDER_TIF_IOC = 3;

  struct LimitOrderAction {
    uint32 asset;
    bool isBuy;
    uint64 limitPx;
    uint64 sz;
    bool reduceOnly;
    uint8 encodedTif;
    uint128 cloid;
  }

  struct VaultTransferAction {
    address vault;
    bool isDeposit;
    uint64 usd;
  }

  struct TokenDelegateAction {
    address validator;
    uint64 _wei;
    bool isUndelegate;
  }

  struct StakingDepositAction {
    uint64 _wei;
  }

  struct StakingWithdrawAction {
    uint64 _wei;
  }

  struct SpotSendAction {
    address destination;
    uint64 token;
    uint64 _wei;
  }

  struct UsdClassTransferAction {
    uint64 ntl;
    bool toPerp;
  }

  function encodeLimitOrderAction(LimitOrderAction memory action) internal pure returns (bytes memory) {
    return abi.encodePacked(CORE_WRITER_VERSION_1, CORE_WRITER_ACTION_LIMIT_ORDER, abi.encode(action));
  }

  function sendLimitOrderAction(LimitOrderAction memory action) internal {
    CoreWriter(CORE_WRITER).sendRawAction(encodeLimitOrderAction(action));
  }

  function encodeVaultTransfer(VaultTransferAction memory action) internal pure returns (bytes memory) {
    return abi.encodePacked(CORE_WRITER_VERSION_1, CORE_WRITER_ACTION_VAULT_TRANSFER, abi.encode(action));
  }

  function sendVaultTransfer(VaultTransferAction memory action) internal {
    CoreWriter(CORE_WRITER).sendRawAction(encodeVaultTransfer(action));
  }

  function encodeTokenDelegate(TokenDelegateAction memory action) internal pure returns (bytes memory) {
    return abi.encodePacked(CORE_WRITER_VERSION_1, CORE_WRITER_ACTION_TOKEN_DELEGATE, abi.encode(action));
  }

  function sendTokenDelegate(TokenDelegateAction memory action) internal {
    CoreWriter(CORE_WRITER).sendRawAction(encodeTokenDelegate(action));
  }

  function encodeStakingDeposit(StakingDepositAction memory action) internal pure returns (bytes memory) {
    return abi.encodePacked(CORE_WRITER_VERSION_1, CORE_WRITER_ACTION_STAKING_DEPOSIT, abi.encode(action));
  }

  function sendStakingDeposit(StakingDepositAction memory action) internal {
    CoreWriter(CORE_WRITER).sendRawAction(encodeStakingDeposit(action));
  }

  function encodeStakingWithdraw(StakingWithdrawAction memory action) internal pure returns (bytes memory) {
    return abi.encodePacked(CORE_WRITER_VERSION_1, CORE_WRITER_ACTION_STAKING_WITHDRAW, abi.encode(action));
  }

  function sendStakingWithdraw(StakingWithdrawAction memory action) internal {
    CoreWriter(CORE_WRITER).sendRawAction(encodeStakingWithdraw(action));
  }

  function encodeSpotSend(SpotSendAction memory action) internal pure returns (bytes memory) {
    return abi.encodePacked(CORE_WRITER_VERSION_1, CORE_WRITER_ACTION_SPOT_SEND, abi.encode(action));
  }

  function sendSpotSend(SpotSendAction memory action) internal {
    CoreWriter(CORE_WRITER).sendRawAction(encodeSpotSend(action));
  }

  function encodeUsdClassTransfer(UsdClassTransferAction memory action) internal pure returns (bytes memory) {
    return abi.encodePacked(CORE_WRITER_VERSION_1, CORE_WRITER_ACTION_USD_CLASS_TRANSFER, abi.encode(action));
  }

  function sendUsdClassTransfer(UsdClassTransferAction memory action) internal {
    CoreWriter(CORE_WRITER).sendRawAction(encodeUsdClassTransfer(action));
  }
}
