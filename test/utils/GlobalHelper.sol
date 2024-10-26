// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Stream } from "../../src/Stream.sol";
import { EventsAndErrors } from "./EventsAndErrors.sol";
import { MockERC20 } from "./MockERC20.sol";

contract GlobalHelper is Test, EventsAndErrors {
    address public owner;
    Stream public stream;

    address public streamer;
    address public recipient;

    MockERC20 public token;

    uint256 public amountToStream = 100e18;
    uint256 public window = 1 minutes;

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

    function _createStream(bool _streamOnce) internal returns (bytes32 streamHash) {
        vm.startPrank(streamer);
        stream.allowStream(address(token), recipient, amountToStream, window, _streamOnce);
        vm.stopPrank();

        streamHash = stream.computeHash(streamer, address(token), recipient);
    }

    function _batchCreateStreams() internal {
        address[] memory tokens = new address[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory windows = new uint256[](2);
        bool[] memory onces = new bool[](2);

        tokens[0] = address(token);
        tokens[1] = address(token);
        recipients[0] = recipient;
        recipients[1] = owner;
        amounts[0] = amountToStream;
        amounts[1] = amountToStream;
        windows[0] = window;
        windows[1] = window;
        onces[0] = true;
        onces[1] = true;

        vm.startPrank(streamer);
        stream.batchAllowStream(tokens, recipients, amounts, windows, onces);
        vm.stopPrank();
    }

    function _mintTokensToStreamerAndProvideAllowanceToStream(uint256 _amount) internal {
        vm.startPrank(streamer);
        token.mint(streamer, _amount);
        token.approve(address(stream), _amount);
        vm.stopPrank();
    }
}
