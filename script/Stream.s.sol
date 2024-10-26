// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";

contract StreamScript is Script {
    function run() public {
        vm.startBroadcast();
        vm.stopBroadcast();
    }
}
