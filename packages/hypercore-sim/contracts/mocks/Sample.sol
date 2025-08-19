// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { CoreReaderLib } from "@ambitlabs/hypercore/contracts/CoreReaderLib.sol";

contract SampleReader {
  function readL1BlockNumber() external view returns (uint64) {
    return CoreReaderLib.readL1BlockNumber();
  }
}
