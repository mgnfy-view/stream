// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { GlobalHelper } from "./utils/GlobalHelper.sol";

import { Stream } from "../src/Stream.sol";

contract MiscellaneousTest is GlobalHelper {
    function test_getAvailableFailsIfStreamDoesNotExist() public {
        vm.expectRevert(bytes(STREAM_DOES_NOT_EXIST));
        stream.getAvailable(address(token), streamer, recipient);
    }

    function test_getAvailable() public {
        bool streamOnce = true;

        _createStream(streamOnce);

        vm.warp(block.timestamp + window);

        assertEq(stream.getAvailable(address(token), streamer, recipient), amountToStream);
    }

    function test_getStreamDetails() public {
        bool streamOnce = true;

        bytes32 streamHash = _createStream(streamOnce);
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = streamHash;

        vm.warp(block.timestamp + window);

        (
            uint256[] memory availableAmounts,
            uint8[] memory decimals,
            string[] memory tokenNames,
            string[] memory tokenSymbols,
            Stream.StreamDetails[] memory details
        ) = stream.getStreamDetails(hashes);

        assertEq(availableAmounts[0], amountToStream);
        assertEq(decimals[0], token.decimals());
        assertEq(tokenNames[0], token.name());
        assertEq(tokenSymbols[0], token.symbol());
        assertEq(details[0].streamer, streamer);
        assertEq(details[0].token, address(token));
        assertEq(details[0].recipient, recipient);
        assertEq(details[0].totalStreamed, 0);
        assertEq(details[0].outstanding, amountToStream);
        assertEq(details[0].allowable, amountToStream);
        assertEq(details[0].window, window);
        assertEq(details[0].timestamp, block.timestamp - window);
        assertEq(details[0].once, streamOnce);
    }

    function test_getStreamableFailsIfStreamDoesNotExist() public {
        bytes32 streamHash = keccak256(abi.encodePacked(streamer, address(token), recipient));
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = streamHash;

        vm.expectRevert(bytes(STREAM_DOES_NOT_EXIST));
        stream.getStreamable(hashes);
    }

    function test_getStreamable() public {
        bool streamOnce = true;

        bytes32 streamHash = _createStream(streamOnce);
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = streamHash;

        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream);

        vm.warp(block.timestamp + window);

        (bool[] memory canStream, uint256[] memory balances, uint256[] memory allowances) = stream.getStreamable(hashes);

        assertEq(canStream[0], true);
        assertEq(balances[0], amountToStream);
        assertEq(allowances[0], amountToStream);
    }

    function test_getStreamerHashes() public {
        bool streamOnce = true;

        bytes32 streamHash = _createStream(streamOnce);

        (bytes32[] memory streamerHashes) = stream.viewStreamerAllowances(streamer);

        assertEq(streamerHashes[0], streamHash);
    }

    function test_getRecipientHashes() public {
        bool streamOnce = true;

        bytes32 streamHash = _createStream(streamOnce);

        (bytes32[] memory recipientHashes) = stream.viewRecipientAllowances(recipient);

        assertEq(recipientHashes[0], streamHash);
    }
}
