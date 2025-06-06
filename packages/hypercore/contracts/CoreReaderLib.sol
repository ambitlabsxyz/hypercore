// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library CoreReaderLib {
  address public constant PRECOMPILE_ADDRESS_POSITION = 0x0000000000000000000000000000000000000800;
  address public constant PRECOMPILE_ADDRESS_SPOT_BALANCE = 0x0000000000000000000000000000000000000801;
  address public constant PRECOMPILE_ADDRESS_VAULT_EQUITY = 0x0000000000000000000000000000000000000802;
  address public constant PRECOMPILE_ADDRESS_WITHDRAWABLE = 0x0000000000000000000000000000000000000803;
  address public constant PRECOMPILE_ADDRESS_DELEGATIONS = 0x0000000000000000000000000000000000000804;
  address public constant PRECOMPILE_ADDRESS_DELEGATOR_SUMMARY = 0x0000000000000000000000000000000000000805;
  address public constant PRECOMPILE_ADDRESS_MARK_PX = 0x0000000000000000000000000000000000000806;
  address public constant PRECOMPILE_ADDRESS_ORACLE_PX = 0x0000000000000000000000000000000000000807;
  address public constant PRECOMPILE_ADDRESS_SPOT_PX = 0x0000000000000000000000000000000000000808;
  address public constant PRECOMPILE_ADDRESS_L1_BLOCK_NUMBER = 0x0000000000000000000000000000000000000809;
  address public constant PRECOMPILE_ADDRESS_PERP_ASSET_INFO = 0x000000000000000000000000000000000000080a;
  address public constant PRECOMPILE_ADDRESS_SPOT_INFO = 0x000000000000000000000000000000000000080b;
  address public constant PRECOMPILE_ADDRESS_TOKEN_INFO = 0x000000000000000000000000000000000000080C;

  error ReadFailure(address precompile);

  struct Position {
    int64 szi;
    uint64 entryNtl;
    int64 isolatedRawUsd;
    uint32 leverage;
    bool isIsolated;
  }

  struct SpotBalance {
    uint64 total;
    uint64 hold;
    uint64 entryNtl;
  }

  struct UserVaultEquity {
    uint64 equity;
    uint64 lockedUntilTimestamp;
  }

  struct Withdrawable {
    uint64 withdrawable;
  }

  struct Delegation {
    address validator;
    uint64 amount;
    uint64 lockedUntilTimestamp;
  }

  struct DelegatorSummary {
    uint64 delegated;
    uint64 undelegated;
    uint64 totalPendingWithdrawal;
    uint64 nPendingWithdrawals;
  }

  struct PerpAssetInfo {
    string coin;
    uint32 marginTableId;
    uint8 szDecimals;
    uint8 maxLeverage;
    bool onlyIsolated;
  }

  struct SpotInfo {
    string name;
    uint64[2] tokens;
  }

  struct TokenInfo {
    string name;
    uint64[] spots;
    uint64 deployerTradingFeeShare;
    address deployer;
    address evmContract;
    uint8 szDecimals;
    uint8 weiDecimals;
    int8 evmExtraWeiDecimals;
  }

  function readPosition(address user, uint16 perp) external view returns (Position memory) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_POSITION.staticcall(abi.encode(user, perp));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (Position));
  }

  function readSpotBalance(address user, uint64 token) external view returns (SpotBalance memory) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_SPOT_BALANCE.staticcall(abi.encode(user, token));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (SpotBalance));
  }

  function readUserVaultEquity(address user, address vault) external view returns (UserVaultEquity memory) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_VAULT_EQUITY.staticcall(abi.encode(user, vault));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (UserVaultEquity));
  }

  function readWithdrawable(address user) external view returns (Withdrawable memory) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_WITHDRAWABLE.staticcall(abi.encode(user));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (Withdrawable));
  }

  function readDelegations(address user) external view returns (Delegation[] memory) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_DELEGATIONS.staticcall(abi.encode(user));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (Delegation[]));
  }

  function readDelegatorSummary(address user) external view returns (DelegatorSummary memory) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_DELEGATOR_SUMMARY.staticcall(abi.encode(user));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (DelegatorSummary));
  }

  function readMarkPx(uint32 index) external view returns (uint64) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_MARK_PX.staticcall(abi.encode(index));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (uint64));
  }

  function readOraclePx(uint32 index) external view returns (uint64) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_ORACLE_PX.staticcall(abi.encode(index));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (uint64));
  }

  function readSpotPx(uint32 index) external view returns (uint64) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_SPOT_PX.staticcall(abi.encode(index));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (uint64));
  }

  function readL1BlockNumber() external view returns (uint64) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_L1_BLOCK_NUMBER.staticcall(abi.encode());
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (uint64));
  }

  function readPerpAssetInfo(uint32 perp) external view returns (PerpAssetInfo memory) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_PERP_ASSET_INFO.staticcall(abi.encode(perp));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (PerpAssetInfo));
  }

  function readSpotInfo(uint32 spot) external view returns (SpotInfo memory) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_SPOT_INFO.staticcall(abi.encode(spot));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (SpotInfo));
  }

  function readTokenInfo(uint32 token) external view returns (TokenInfo memory) {
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS_TOKEN_INFO.staticcall(abi.encode(token));
    require(success, ReadFailure(PRECOMPILE_ADDRESS_POSITION));
    return abi.decode(result, (TokenInfo));
  }
}
