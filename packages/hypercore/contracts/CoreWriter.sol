// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface CoreWriter {
  event RawAction(address indexed user, bytes data);

  function sendRawAction(bytes calldata data) external;
}
