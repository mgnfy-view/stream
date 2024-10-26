// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { GlobalHelper } from "./utils/GlobalHelper.sol";

contract StreamTest is GlobalHelper {
    uint256 public amountToStream = 100e18;
    uint256 public window = 1 minutes;

    function test_computeHash() public view {
        bytes32 expectedHash = keccak256(abi.encodePacked(streamer, address(token), recipient));

        assertEq(stream.computeHash(streamer, address(token), recipient), expectedHash);
    }

    function test_createNewStream() public {
        bool streamOnce = true;

        bytes32 streamHash = _createStream(streamOnce);

        (
            address actualStreamer,
            address actualRecipient,
            address actualToken,
            uint256 totalStreamed,
            uint256 outstanding,
            uint256 allowable,
            uint256 actualWindow,
            uint256 timestamp,
            bool once
        ) = stream.streamDetails(streamHash);
        bytes32[] memory streamDetailsByStreamer = stream.viewStreamerAllowances(streamer);
        bytes32[] memory streamDetailsByRecipient = stream.viewRecipientAllowances(recipient);

        assertEq(actualStreamer, streamer);
        assertEq(actualRecipient, recipient);
        assertEq(actualToken, address(token));
        assertEq(totalStreamed, 0);
        assertEq(outstanding, amountToStream);
        assertEq(allowable, amountToStream);
        assertEq(actualWindow, window);
        assertEq(timestamp, block.timestamp);
        assertEq(once, streamOnce);

        assertEq(streamDetailsByStreamer.length, 1);
        assertEq(streamDetailsByRecipient.length, 1);
        assertEq(streamDetailsByStreamer[0], streamHash);
        assertEq(streamDetailsByRecipient[0], streamHash);
    }

    function test_overwriteStream() public {
        bool streamOnce = true;

        bytes32 streamHash = _createStream(streamOnce);

        uint256 newAmountToStream = 50e18;
        uint256 newWindow = 2 minutes;
        bool newStreamOnceFlag = !streamOnce;

        vm.startPrank(streamer);
        stream.allowStream(address(token), recipient, newAmountToStream, newWindow, newStreamOnceFlag);
        vm.stopPrank();

        (,,,, uint256 outstanding, uint256 allowable, uint256 actualWindow, uint256 timestamp, bool once) =
            stream.streamDetails(streamHash);

        assertEq(outstanding, newAmountToStream);
        assertEq(allowable, newAmountToStream);
        assertEq(actualWindow, newWindow);
        assertEq(timestamp, block.timestamp);
        assertEq(once, newStreamOnceFlag);
    }

    function test_creatingAStreamEmitsEvent() public {
        bool streamOnce = true;

        vm.startPrank(streamer);
        vm.expectEmit(true, true, true, true);
        emit StreamAllowed(streamer, address(token), recipient, amountToStream);
        stream.allowStream(address(token), recipient, amountToStream, window, streamOnce);
        vm.stopPrank();
    }

    function test_collectingFundsFromANonExistentStreamFails() public {
        vm.expectRevert(bytes(STREAM_DOES_NOT_EXIST));
        stream.stream(address(token), owner, recipient);
    }

    function test_collectingZeroFundsFromStreamFails() public {
        bool streamOnce = true;

        _createStream(streamOnce);

        vm.expectRevert(bytes(NO_ALLOWABLE_AMOUNT_TO_WITHDRAW));
        stream.stream(address(token), streamer, recipient);
    }

    function test_collectFundsFromStreamOnceHalfWayThroughWindow() public {
        bool streamOnce = true;

        bytes32 streamHash = _createStream(streamOnce);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream);

        vm.warp(block.timestamp + window / 2);

        stream.stream(address(token), streamer, recipient);

        (,,, uint256 totalStreamed, uint256 outstanding,,, uint256 timestamp,) = stream.streamDetails(streamHash);

        assertEq(token.balanceOf(streamer), amountToStream / 2);
        assertEq(token.balanceOf(recipient), amountToStream / 2);

        assertEq(totalStreamed, amountToStream / 2);
        assertEq(outstanding, amountToStream / 2);
        assertEq(timestamp, block.timestamp);
    }

    function test_collectAllFundsFromStreamOnce() public {
        bool streamOnce = true;

        bytes32 streamHash = _createStream(streamOnce);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream);

        vm.warp(block.timestamp + window);

        stream.stream(address(token), streamer, recipient);

        (,,, uint256 totalStreamed, uint256 outstanding,,, uint256 timestamp,) = stream.streamDetails(streamHash);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream);

        assertEq(totalStreamed, amountToStream);
        assertEq(outstanding, 0);
        assertEq(timestamp, block.timestamp);
    }

    function test_collectAllFundsFromStreamOnceWayPastWindow() public {
        bool streamOnce = true;

        bytes32 streamHash = _createStream(streamOnce);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream);

        vm.warp(block.timestamp + window + 1 minutes);

        stream.stream(address(token), streamer, recipient);

        (,,, uint256 totalStreamed, uint256 outstanding,,, uint256 timestamp,) = stream.streamDetails(streamHash);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream);

        assertEq(totalStreamed, amountToStream);
        assertEq(outstanding, 0);
        assertEq(timestamp, block.timestamp);
    }

    function test_collectFundsFromRecurringStream() public {
        bool streamOnce = false;

        bytes32 streamHash = _createStream(streamOnce);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream);

        vm.warp(block.timestamp + window);

        stream.stream(address(token), streamer, recipient);

        (,,, uint256 totalStreamed, uint256 outstanding,,, uint256 timestamp,) = stream.streamDetails(streamHash);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream);

        assertEq(totalStreamed, amountToStream);
        assertEq(outstanding, amountToStream);
        assertEq(timestamp, block.timestamp);

        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream);

        vm.warp(block.timestamp + window);

        stream.stream(address(token), streamer, recipient);

        (,,, totalStreamed, outstanding,,, timestamp,) = stream.streamDetails(streamHash);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream * 2);

        assertEq(totalStreamed, amountToStream * 2);
        assertEq(outstanding, amountToStream);
        assertEq(timestamp, block.timestamp);
    }

    function test_collectFundsFromRecurringStreamWayPastWindow() public {
        bool streamOnce = false;

        bytes32 streamHash = _createStream(streamOnce);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream * 2);

        vm.warp(block.timestamp + window * 2);

        stream.stream(address(token), streamer, recipient);

        (,,, uint256 totalStreamed, uint256 outstanding,,, uint256 timestamp,) = stream.streamDetails(streamHash);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream * 2);

        assertEq(totalStreamed, amountToStream * 2);
        assertEq(outstanding, amountToStream);
        assertEq(timestamp, block.timestamp);
    }

    function test_collectFundsFromStreamWithFees() public {
        uint256 newFee = 10;
        uint256 feeAmount = (amountToStream * newFee) / 1000;

        vm.startPrank(owner);
        stream.setFee(newFee, address(0));
        vm.stopPrank();

        bool streamOnce = true;

        _createStream(streamOnce);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream + feeAmount);

        vm.warp(block.timestamp + window);

        stream.stream(address(token), streamer, recipient);

        assertEq(token.balanceOf(streamer), 0);
        assertEq(token.balanceOf(recipient), amountToStream);
        assertEq(token.balanceOf(owner), feeAmount);
    }

    function test_collectingFundsFromStreamEmitsEvent() public {
        bool streamOnce = false;

        _createStream(streamOnce);
        _mintTokensToStreamerAndProvideAllowanceToStream(amountToStream);

        vm.warp(block.timestamp + window);

        vm.expectEmit(true, true, true, true);
        emit Streamed(address(token), streamer, recipient, amountToStream);
        stream.stream(address(token), streamer, recipient);
    }

    function test_cancelStreamFailsIfInputArraysDoNotMatch() public {
        address[] memory tokens = new address[](2);
        address[] memory streamers = new address[](1);
        address[] memory recipients = new address[](2);

        vm.startPrank(streamer);
        vm.expectRevert(bytes(INPUT_ARRAYS_LENGTH_MISMATCH));
        stream.cancelStreams(tokens, streamers, recipients);
    }

    function test_cancelStreamFailsIfCallerIsNotStreamerOrRecipient() public {
        address[] memory tokens = new address[](2);
        address[] memory streamers = new address[](2);
        address[] memory recipients = new address[](2);

        vm.startPrank(owner);
        vm.expectRevert(bytes(YOU_ARE_NOT_THE_STREAMER_OR_RECIPIENT));
        stream.cancelStreams(tokens, streamers, recipients);
    }

    function test_cancelStreamFailsIfStreamDoesNotExist() public {
        address[] memory tokens = new address[](1);
        address[] memory streamers = new address[](1);
        address[] memory recipients = new address[](1);

        tokens[0] = address(token);
        streamers[0] = streamer;
        recipients[0] = recipient;

        vm.startPrank(streamer);
        vm.expectRevert(bytes(STREAM_DOES_NOT_EXIST));
        stream.cancelStreams(tokens, streamers, recipients);
    }

    function test_cancelStream() public {
        bool streamOnce = true;
        bytes32 streamHash = _createStream(streamOnce);

        address[] memory tokens = new address[](1);
        address[] memory streamers = new address[](1);
        address[] memory recipients = new address[](1);

        tokens[0] = address(token);
        streamers[0] = streamer;
        recipients[0] = recipient;

        vm.startPrank(streamer);
        stream.cancelStreams(tokens, streamers, recipients);

        (,,,, uint256 outstanding, uint256 allowable,,,) = stream.streamDetails(streamHash);

        assertEq(outstanding, 0);
        assertEq(allowable, 0);
    }

    function test_cancelStreamEmitsEvent() public {
        bool streamOnce = true;
        _createStream(streamOnce);

        address[] memory tokens = new address[](1);
        address[] memory streamers = new address[](1);
        address[] memory recipients = new address[](1);

        tokens[0] = address(token);
        streamers[0] = streamer;
        recipients[0] = recipient;

        vm.startPrank(streamer);
        vm.expectEmit(true, true, true, true);
        emit StreamAllowed(streamer, address(token), recipient, 0);
        stream.cancelStreams(tokens, streamers, recipients);
    }

    function _createStream(bool _streamOnce) internal returns (bytes32 streamHash) {
        vm.startPrank(streamer);
        stream.allowStream(address(token), recipient, amountToStream, window, _streamOnce);
        vm.stopPrank();

        streamHash = stream.computeHash(streamer, address(token), recipient);
    }

    function _mintTokensToStreamerAndProvideAllowanceToStream(uint256 _amount) internal {
        vm.startPrank(streamer);
        token.mint(streamer, _amount);
        token.approve(address(stream), _amount);
        vm.stopPrank();
    }
}
