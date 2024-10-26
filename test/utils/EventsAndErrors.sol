// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract EventsAndErrors {
    event StreamAllowed(address indexed streamer, address indexed token, address indexed recipient, uint256 amount);
    event Streamed(address indexed token, address indexed streamer, address indexed recipient, uint256 amount);
    event StreamFailure(address indexed token, address indexed streamer, address indexed recipient, string message);

    string public constant STREAM_DOES_NOT_EXIST = "Stream does not exist";
    string public constant YOU_ARE_NOT_THE_OWNER = "You are not the owner";
    string public constant NO_ALLOWABLE_AMOUNT_TO_WITHDRAW = "No allowable amount to withdraw";
    string public constant INPUT_ARRAYS_LENGTH_MISMATCH = "Input arrays length mismatch";
    string public constant INSUFFICIENT_BALANCE_FOR_STREAMING = "Insufficient balance for streaming";
    string public constant INSUFFICIENT_ALLOWANCE_FOR_STREAMING = "Insufficient allowance for streaming";
    string public constant YOU_ARE_NOT_THE_STREAMER_OR_RECIPIENT = "You are not the streamer or recipient";
}
