// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { CoreReaderLib } from "@ambitlabs/hypercore/contracts/CoreReaderLib.sol";
import { HyperCore } from "./HyperCore.sol";

/// @dev this contract is deployed for each different precompile address such that the fallback can be executed for each
contract HyperCorePrecompiles {
  HyperCore private _hyperCore;

  receive() external payable {}

  function setHyperCore(HyperCore hyperCore) public {
    _hyperCore = hyperCore;
  }

  fallback(bytes calldata data) external returns (bytes memory) {
    if (address(this) == CoreReaderLib.PRECOMPILE_ADDRESS_SPOT_BALANCE) {
      (address user, uint64 token) = abi.decode(data, (address, uint64));
      return abi.encode(_hyperCore.readSpotBalance(user, token));
    }

    if (address(this) == CoreReaderLib.PRECOMPILE_ADDRESS_VAULT_EQUITY) {
      (address user, address vault) = abi.decode(data, (address, address));
      return abi.encode(_hyperCore.readUserVaultEquity(user, vault));
    }

    if (address(this) == CoreReaderLib.PRECOMPILE_ADDRESS_WITHDRAWABLE) {
      address user = abi.decode(data, (address));
      return abi.encode(_hyperCore.readWithdrawable(user));
    }

    if (address(this) == CoreReaderLib.PRECOMPILE_ADDRESS_DELEGATIONS) {
      address user = abi.decode(data, (address));
      return abi.encode(_hyperCore.readDelegations(user));
    }

    if (address(this) == CoreReaderLib.PRECOMPILE_ADDRESS_DELEGATOR_SUMMARY) {
      address user = abi.decode(data, (address));
      return abi.encode(_hyperCore.readDelegatorSummary(user));
    }

    if (address(this) == CoreReaderLib.PRECOMPILE_ADDRESS_POSITION) {
      (address user, uint16 perp) = abi.decode(data, (address, uint16));
      return abi.encode(_hyperCore.readPosition(user, perp));
    }

    revert();
  }
}
