// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { CoreWriter } from "@ambitlabs/hypercore/contracts/CoreWriter.sol";
import { HyperCore } from "./HyperCore.sol";

contract HyperCoreWrite is CoreWriter {
  using Address for address;

  bytes[] private _actionQueue;

  uint256[] private _actionQueueValues;

  HyperCore private _hyperCore;

  function setHyperCore(HyperCore hyperCore) public {
    _hyperCore = hyperCore;
  }

  function enqueueAction(bytes memory data, uint256 value) public {
    _actionQueue.push(data);
    _actionQueueValues.push(value);
  }

  function flushActionQueue() external {
    for (uint256 i = 0; i < _actionQueue.length; i++) {
      address(_hyperCore).functionCallWithValue(_actionQueue[i], _actionQueueValues[i]);
    }

    delete _actionQueue;
    delete _actionQueueValues;

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

    enqueueAction(abi.encodeCall(HyperCore.executeRawAction, (msg.sender, kind, data[4:])), 0);

    emit RawAction(msg.sender, data);
  }
}
