// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { HyperCore } from "./HyperCore.sol";

library SerializationLib {
  function serializeWithdrawRequest(HyperCore.WithdrawRequest memory request) internal pure returns (bytes32) {
    return
      bytes32(
        (uint256(uint160(request.account)) << 96) |
          (uint256(request.amount) << 32) |
          uint40(request.lockedUntilTimestamp)
      );
  }

  function deserializeWithdrawRequest(bytes32 data) internal pure returns (HyperCore.WithdrawRequest memory request) {
    request.account = address(uint160(uint256(data) >> 96));
    request.amount = uint64(uint256(data) >> 32);
    request.lockedUntilTimestamp = uint32(uint256(data));
  }
}
