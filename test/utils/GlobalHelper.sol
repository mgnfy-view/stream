// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Stream } from "../../src/Stream.sol";
import { MockERC20 } from "./MockERC20.sol";

contract GlobalHelper is Test {
    address public owner;
    Stream public stream;

    address public streamer;
    address public recipient;

    MockERC20 public token;

    function setUp() public {
        owner = makeAddr("owner");

        vm.startPrank(owner);
        stream = new Stream(payable(owner));
        vm.stopPrank();

        streamer = makeAddr("streamer");
        recipient = makeAddr("recipient");

        string memory tokenName = "Mock ERC20";
        string memory tokenSymbol = "MERC20";
        token = new MockERC20(tokenName, tokenSymbol);
    }
}
