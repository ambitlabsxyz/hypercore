// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Heap } from "@openzeppelin/contracts/utils/structs/Heap.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { CoreWriter } from "@ambitlabs/hypercore/contracts/CoreWriter.sol";
import { CoreWriterLib } from "@ambitlabs/hypercore/contracts/CoreWriterLib.sol";
import { HyperCore } from "./HyperCore.sol";

contract HyperCoreWrite is CoreWriter {
  using Address for address;
  using Heap for Heap.Uint256Heap;

  uint128 private _sequence;

  Heap.Uint256Heap private _actionQueue;

  struct Action {
    uint256 timestamp;
    bytes data;
    uint256 value;
  }

  mapping(uint256 id => Action) _actions;

  HyperCore private _hyperCore;

  function setHyperCore(HyperCore hyperCore) public {
    _hyperCore = hyperCore;
  }

  function enqueueAction(bytes memory data, uint256 value) public {
    enqueueAction(block.timestamp, data, value);
  }

  function enqueueAction(uint256 timestamp, bytes memory data, uint256 value) public {
    uint256 uniqueId = (uint256(timestamp) << 128) | uint256(_sequence++);

    _actions[uniqueId] = Action(timestamp, data, value);
    _actionQueue.insert(uniqueId);
  }

  function flushActionQueue() external {
    while (_actionQueue.length() > 0) {
      Action memory action = _actions[_actionQueue.peek()];

      // the action queue is a priority queue so the timestamp takes precedence in the
      // ordering which means we can safely stop processing if the actions are delayed
      if (action.timestamp > block.timestamp) {
        break;
      }

      address(_hyperCore).functionCallWithValue(action.data, action.value);

      _actionQueue.pop();
    }

    _hyperCore.flushCWithdrawQueue();
  }

  function tokenTransferCallback(uint64 token, address from, uint256 value) public {
    // there's a special case when transferring to the L1 via the system address which
    // is that the balance isn't reflected on the L1 until after the EVM block has finished
    // and the subsequent EVM block has been processed, this means that the balance can be
    // in limbo for the user
    tokenTransferCallback(msg.sender, token, from, value);
  }

  function tokenTransferCallback(address sender, uint64 token, address from, uint256 value) public {
    enqueueAction(abi.encodeCall(HyperCore.executeTokenTransfer, (sender, token, from, value)), 0);
  }

  function nativeTransferCallback(address sender, address from, uint256 value) public payable {
    enqueueAction(abi.encodeCall(HyperCore.executeNativeTransfer, (sender, from, value)), value);
  }

  function sendRawAction(bytes calldata data) external {
    uint8 version = uint8(data[0]);
    require(version == 1);

    uint24 kind = (uint24(uint8(data[1])) << 16) | (uint24(uint8(data[2])) << 8) | (uint24(uint8(data[3])));

    bytes memory call = abi.encodeCall(HyperCore.executeRawAction, (msg.sender, kind, data[4:]));

    enqueueAction(runAt(kind, data[4:]), call, 0);

    emit RawAction(msg.sender, data);
  }

  /// @dev some actions are delayed before they are executed so need to simulate this
  function runAt(uint24 kind, bytes memory data) private view returns (uint256) {
    if (kind == CoreWriterLib.CORE_WRITER_ACTION_VAULT_TRANSFER) {
      // there is a 4 second delay for vault withdrawls
      //CoreWriterLib.VaultTransferAction memory action = abi.decode(data, (CoreWriterLib.VaultTransferAction));
      //return action.isDeposit ? block.timestamp : block.timestamp + 4 seconds;
      return block.timestamp + 4 seconds;
    }
    return block.timestamp;
  }
}
