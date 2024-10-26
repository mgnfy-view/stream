// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";

import { Stream } from "../src/Stream.sol";

contract StreamScript is Script {
    Stream public stream;

    function run() public {
        vm.startBroadcast();
        stream = new Stream(payable(msg.sender));
        vm.stopBroadcast();
    }
}
