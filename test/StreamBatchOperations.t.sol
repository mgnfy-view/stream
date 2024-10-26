// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { GlobalHelper } from "./utils/GlobalHelper.sol";

contract StreamBatchOperationsTest is GlobalHelper {
    function test_batchAllowStreamFailsIfInputArrayLengthsDoNotMatch() public {
        address[] memory tokens = new address[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory windows = new uint256[](1);
        bool[] memory onces = new bool[](2);

        vm.startPrank(streamer);
        vm.expectRevert(bytes(INPUT_ARRAYS_LENGTH_MISMATCH));
        stream.batchAllowStream(tokens, recipients, amounts, windows, onces);
        vm.stopPrank();
    }

    function test_batchAllowStreams() public {
        _batchCreateStreams();
    }

    function test_batchCollectFromStreamsFailsIfInputArrayLengthsDoNotMatch() public {
        address[] memory tokens = new address[](1);
        address[] memory streamers = new address[](2);
        address[] memory recipients = new address[](2);

        tokens[0] = address(token);
        streamers[0] = streamer;
        streamers[1] = streamer;
        recipients[0] = recipient;
        recipients[1] = owner;

        vm.expectRevert(bytes(INPUT_ARRAYS_LENGTH_MISMATCH));
        stream.batchStream(tokens, streamers, recipients);
    }

    function test_batchCollectFundsFromStreams() public {
        _batchCreateStreams();
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream * 2);

        vm.warp(block.timestamp + window);

        address[] memory tokens = new address[](2);
        address[] memory streamers = new address[](2);
        address[] memory recipients = new address[](2);

        tokens[0] = address(token);
        tokens[1] = address(token);
        streamers[0] = streamer;
        streamers[1] = streamer;
        recipients[0] = recipient;
        recipients[1] = owner;

        stream.batchStream(tokens, streamers, recipients);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream);
        assertEq(token.balanceOf(owner), amountToStream);
    }

    function test_batchCollectFundsFromStreamWithFees() public {
        uint256 newFee = 10;
        uint256 feeAmount = (amountToStream * newFee) / 1000;

        vm.startPrank(owner);
        stream.setFee(newFee, address(0));
        vm.stopPrank();

        _batchCreateStreams();
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream * 2 + feeAmount * 2);

        vm.warp(block.timestamp + window);

        address[] memory tokens = new address[](2);
        address[] memory streamers = new address[](2);
        address[] memory recipients = new address[](2);

        tokens[0] = address(token);
        tokens[1] = address(token);
        streamers[0] = streamer;
        streamers[1] = streamer;
        recipients[0] = recipient;
        recipients[1] = owner;

        stream.batchStream(tokens, streamers, recipients);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream);
        assertEq(token.balanceOf(owner), amountToStream + feeAmount * 2);
    }

    function test_batchStreamAvailableFailsIfInputArrayLengthsDoNotMatch() public {
        address[] memory tokens = new address[](1);
        address[] memory streamers = new address[](2);
        address[] memory recipients = new address[](2);

        tokens[0] = address(token);
        streamers[0] = streamer;
        streamers[1] = streamer;
        recipients[0] = recipient;
        recipients[1] = owner;

        vm.expectRevert(bytes(INPUT_ARRAYS_LENGTH_MISMATCH));
        stream.batchStreamAvailable(tokens, streamers, recipients);
    }

    function test_batchStreamAvailableEmitsStreamFailureIfStreamDoesNotExist() public {
        address[] memory tokens = new address[](1);
        address[] memory streamers = new address[](1);
        address[] memory recipients = new address[](1);

        tokens[0] = address(token);
        streamers[0] = streamer;
        recipients[0] = recipient;

        vm.expectEmit(true, true, true, true);
        emit StreamFailure(address(token), streamer, recipient, STREAM_DOES_NOT_EXIST);
        stream.batchStreamAvailable(tokens, streamers, recipients);
    }

    function test_batchStreamAvailableEmitsStreamFailureIfAmountToWithdrawIsZero() public {
        _batchCreateStreams();

        address[] memory tokens = new address[](1);
        address[] memory streamers = new address[](1);
        address[] memory recipients = new address[](1);

        tokens[0] = address(token);
        streamers[0] = streamer;
        recipients[0] = recipient;

        vm.expectEmit(true, true, true, true);
        emit StreamFailure(address(token), streamer, recipient, NO_ALLOWABLE_AMOUNT_TO_WITHDRAW);
        stream.batchStreamAvailable(tokens, streamers, recipients);
    }

    function test_batchStreamAvailableEmitsStreamFailureIfStreamerHasInsufficientBalance() public {
        _batchCreateStreams();

        address[] memory tokens = new address[](1);
        address[] memory streamers = new address[](1);
        address[] memory recipients = new address[](1);

        tokens[0] = address(token);
        streamers[0] = streamer;
        recipients[0] = recipient;

        vm.warp(block.timestamp + window);

        vm.expectEmit(true, true, true, true);
        emit StreamFailure(address(token), streamer, recipient, INSUFFICIENT_BALANCE_FOR_STREAMING);
        stream.batchStreamAvailable(tokens, streamers, recipients);
    }

    function test_batchStreamAvailableEmitsStreamFailureIfStreamerHasNotApprovedTokensToStream() public {
        _batchCreateStreams();

        address[] memory tokens = new address[](1);
        address[] memory streamers = new address[](1);
        address[] memory recipients = new address[](1);

        tokens[0] = address(token);
        streamers[0] = streamer;
        recipients[0] = recipient;

        vm.warp(block.timestamp + window);
        token.mint(streamer, amountToStream);

        vm.expectEmit(true, true, true, true);
        emit StreamFailure(address(token), streamer, recipient, INSUFFICIENT_ALLOWANCE_FOR_STREAMING);
        stream.batchStreamAvailable(tokens, streamers, recipients);
    }

    function test_batchStreamAvailable() public {
        _batchCreateStreams();

        address[] memory tokens = new address[](2);
        address[] memory streamers = new address[](2);
        address[] memory recipients = new address[](2);

        tokens[0] = address(token);
        tokens[1] = address(token);
        streamers[0] = streamer;
        streamers[1] = streamer;
        recipients[0] = recipient;
        recipients[1] = owner;

        vm.warp(block.timestamp + window);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream * 2);

        stream.batchStreamAvailable(tokens, streamers, recipients);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream);
        assertEq(token.balanceOf(owner), amountToStream);
    }

    function test_batchStreamAvailableWithFees() public {
        uint256 newFee = 10;
        uint256 feeAmount = (amountToStream * newFee) / 1000;

        vm.startPrank(owner);
        stream.setFee(newFee, address(0));
        vm.stopPrank();

        _batchCreateStreams();

        address[] memory tokens = new address[](2);
        address[] memory streamers = new address[](2);
        address[] memory recipients = new address[](2);

        tokens[0] = address(token);
        tokens[1] = address(token);
        streamers[0] = streamer;
        streamers[1] = streamer;
        recipients[0] = recipient;
        recipients[1] = owner;

        vm.warp(block.timestamp + window);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream * 2 + feeAmount * 2);

        stream.batchStreamAvailable(tokens, streamers, recipients);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream);
        assertEq(token.balanceOf(owner), amountToStream + feeAmount * 2);
    }

    function test_batchStreamAvailableEmitsEvent() public {
        _batchCreateStreams();

        address[] memory tokens = new address[](2);
        address[] memory streamers = new address[](2);
        address[] memory recipients = new address[](2);

        tokens[0] = address(token);
        tokens[1] = address(token);
        streamers[0] = streamer;
        streamers[1] = streamer;
        recipients[0] = recipient;
        recipients[1] = owner;

        vm.warp(block.timestamp + window);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream * 2);

        vm.expectEmit(true, true, true, true);
        emit Streamed(address(token), streamer, recipient, amountToStream);
        emit Streamed(address(token), streamer, owner, amountToStream);
        stream.batchStreamAvailable(tokens, streamers, recipients);
    }

    function test_batchStreamAvailableWithStreamHashes() public {
        _batchCreateStreams();
        bytes32[] memory streamHashes = new bytes32[](2);
        streamHashes[0] = stream.computeHash(streamer, address(token), recipient);
        streamHashes[1] = stream.computeHash(streamer, address(token), owner);

        vm.warp(block.timestamp + window);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream * 2);

        stream.batchStreamAvailableAllowances(streamHashes);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream);
        assertEq(token.balanceOf(owner), amountToStream);
    }

    function test_batchComputeHashes() public view {
        address[] memory streamers = new address[](2);
        address[] memory tokens = new address[](2);
        address[] memory recipients = new address[](2);

        streamers[0] = streamer;
        streamers[1] = streamer;
        tokens[0] = address(token);
        tokens[1] = address(token);
        recipients[0] = recipient;
        recipients[1] = owner;

        bytes32 expectedHash1 = keccak256(abi.encodePacked(streamer, address(token), recipient));
        bytes32 expectedHash2 = keccak256(abi.encodePacked(streamer, address(token), owner));

        bytes32[] memory streamHashes = stream.batchComputeHash(streamers, tokens, recipients);

        assertEq(expectedHash1, streamHashes[0]);
        assertEq(expectedHash2, streamHashes[1]);
    }
}
