// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/utils/Address.sol";

contract Stream {
    using SafeERC20 for IERC20;

    struct StreamDetails {
        address streamer;
        address recipient;
        address token;
        uint256 totalStreamed;
        uint256 outstanding;
        uint256 allowable;
        uint256 window;
        uint256 timestamp;
        bool once;
    }

    mapping(bytes32 => StreamDetails) public streamDetails;
    mapping(address => bytes32[]) public streamDetailsByStreamer;
    mapping(address => bytes32[]) public streamDetailsByRecipient;
    address payable public feeAddress;
    uint256 public fee;

    event StreamAllowed(address indexed streamer, address indexed token, address indexed recipient, uint256 amount);
    event Streamed(address indexed token, address indexed streamer, address indexed recipient, uint256 amount);
    event StreamFailure(address indexed token, address indexed streamer, address indexed recipient, string message);

    constructor(address payable feeAddrs) {
        feeAddress = feeAddrs;
    }

    function computeHash(address streamer, address token, address recipient) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(streamer, token, recipient));
    }

    function allowStream(address token, address recipient, uint256 amount, uint256 window, bool once) public {
        bytes32 hash = computeHash(msg.sender, token, recipient);
        if (streamDetails[hash].streamer == address(0)) {
            streamDetails[hash] = StreamDetails({
                streamer: msg.sender,
                recipient: recipient,
                token: token,
                totalStreamed: 0,
                outstanding: amount,
                allowable: amount,
                window: window,
                timestamp: block.timestamp,
                once: once
            });
            streamDetailsByStreamer[msg.sender].push(hash);
            streamDetailsByRecipient[recipient].push(hash);
        } else {
            streamDetails[hash].allowable = amount;
            streamDetails[hash].outstanding = amount;
            streamDetails[hash].window = window;
            streamDetails[hash].timestamp = block.timestamp;
            streamDetails[hash].once = once;
        }
        emit StreamAllowed(msg.sender, token, recipient, amount);
    }

    function stream(address token, address streamer, address recipient) public {
        bytes32 hash = computeHash(streamer, token, recipient);
        StreamDetails storage details = streamDetails[hash];
        require(details.streamer != address(0), "Stream does not exist");

        uint256 currentTime = block.timestamp;
        uint256 elapsedTime = currentTime - details.timestamp;
        uint256 allowableAmount = (details.allowable * elapsedTime) / details.window;

        if (allowableAmount > details.outstanding && details.once == true) {
            allowableAmount = details.outstanding;
        }

        require(allowableAmount > 0, "No allowable amount to withdraw");

        if (details.once) {
            details.outstanding -= allowableAmount;
        }

        details.totalStreamed += allowableAmount;
        details.timestamp = currentTime;
        IERC20(token).safeTransferFrom(streamer, recipient, allowableAmount);

        if (fee > 0) {
            uint256 feeAmount = (allowableAmount * fee) / 1000;
            IERC20(token).safeTransferFrom(streamer, feeAddress, feeAmount);
        }
        emit Streamed(token, streamer, recipient, allowableAmount);
    }

    function batchAllowStream(
        address[] calldata tokens,
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint256[] calldata windows,
        bool[] calldata onces
    )
        external
    {
        require(
            tokens.length == recipients.length && recipients.length == amounts.length
                && amounts.length == windows.length && windows.length == onces.length,
            "Input arrays length mismatch"
        );

        for (uint256 i = 0; i < tokens.length; i++) {
            allowStream(tokens[i], recipients[i], amounts[i], windows[i], onces[i]);
        }
    }

    function batchStream(
        address[] calldata tokens,
        address[] calldata streamers,
        address[] calldata recipients
    )
        external
    {
        require(
            tokens.length == streamers.length && streamers.length == recipients.length, "Input arrays length mismatch"
        );

        for (uint256 i = 0; i < tokens.length; i++) {
            stream(tokens[i], streamers[i], recipients[i]);
        }
    }

    function batchStreamAvailable(
        address[] memory tokens,
        address[] memory streamers,
        address[] memory recipients
    )
        public
    {
        require(
            tokens.length == streamers.length && streamers.length == recipients.length, "Input arrays length mismatch"
        );

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            address streamer = streamers[i];
            address recipient = recipients[i];

            bytes32 hash = computeHash(streamer, token, recipient);
            StreamDetails storage details = streamDetails[hash];

            // Check if the stream exists, if not log and continue to the next one
            if (details.streamer == address(0)) {
                emit StreamFailure(token, streamer, recipient, "Stream does not exist");
                continue;
            }

            uint256 currentTime = block.timestamp;
            uint256 elapsedTime = currentTime - details.timestamp;
            uint256 allowableAmount = (details.allowable * elapsedTime) / details.window;

            if (allowableAmount > details.outstanding && details.once == true) {
                allowableAmount = details.outstanding;
            }

            // If there's no allowable amount to withdraw, log and continue to the next one
            if (allowableAmount == 0) {
                emit StreamFailure(token, streamer, recipient, "No allowable amount to withdraw");
                continue;
            }

            // Calculate fee if applicable
            uint256 feeAmount = 0;
            if (fee > 0) {
                feeAmount = (allowableAmount * fee) / 1000;
            }
            uint256 totalAmountToTransfer = allowableAmount + feeAmount;

            // Check if streamer has sufficient balance, log and continue if insufficient
            uint256 streamerBalance = IERC20(token).balanceOf(streamer);
            if (streamerBalance < totalAmountToTransfer) {
                emit StreamFailure(token, streamer, recipient, "Insufficient balance for streaming");
                continue;
            }

            // Check if contract has sufficient allowance to transfer tokens, log and continue if insufficient
            uint256 allowance = IERC20(token).allowance(streamer, address(this));
            if (allowance < totalAmountToTransfer) {
                emit StreamFailure(token, streamer, recipient, "Insufficient allowance for streaming");
                continue;
            }

            // Proceed with streaming logic
            if (details.once) {
                details.outstanding -= allowableAmount;
            }

            details.totalStreamed += allowableAmount;
            details.timestamp = currentTime;

            // Transfer allowable amount to recipient
            IERC20(token).safeTransferFrom(streamer, recipient, allowableAmount);

            // Transfer the fee to feeAddress if applicable
            if (feeAmount > 0) {
                IERC20(token).safeTransferFrom(streamer, feeAddress, feeAmount);
            }

            emit Streamed(token, streamer, recipient, allowableAmount);
        }
    }

    function batchStreamAvailableAllowances(bytes32[] memory hashes) external {
        address[] memory tokens = new address[](hashes.length);
        address[] memory streamers = new address[](hashes.length);
        address[] memory recipients = new address[](hashes.length);
        for (uint256 i = 0; i < hashes.length; i++) {
            StreamDetails storage details = streamDetails[hashes[i]];
            tokens[i] = details.token;
            streamers[i] = details.streamer;
            recipients[i] = details.recipient;
        }
        batchStreamAvailable(tokens, streamers, recipients);
    }

    function cancelStreams(
        address[] calldata tokens,
        address[] calldata streamers,
        address[] calldata recipients
    )
        external
    {
        require(
            tokens.length == streamers.length && streamers.length == recipients.length, "Input arrays length mismatch"
        );

        for (uint256 i = 0; i < tokens.length; i++) {
            require(msg.sender == streamers[i] || msg.sender == recipients[i], "You are not the streamer or recipient");
            bytes32 hash = computeHash(streamers[i], tokens[i], recipients[i]);
            StreamDetails storage details = streamDetails[hash];
            require(details.streamer != address(0), "Stream does not exist");
            details.allowable = 0;
            details.outstanding = 0;
            emit StreamAllowed(streamers[i], tokens[i], recipients[i], 0);
        }
    }

    function getAvailable(address token, address streamer, address recipient) public view returns (uint256) {
        bytes32 hash = computeHash(streamer, token, recipient);
        StreamDetails storage details = streamDetails[hash];
        require(details.streamer != address(0), "Stream does not exist");

        uint256 currentTime = block.timestamp;
        uint256 elapsedTime = currentTime - details.timestamp;
        uint256 allowableAmount = (details.allowable * elapsedTime) / details.window;

        if (allowableAmount > details.outstanding && details.once == true) {
            allowableAmount = details.outstanding;
        }

        return allowableAmount;
    }

    function getStreamDetails(
        bytes32[] calldata hashes
    )
        public
        view
        returns (
            uint256[] memory availableAmounts,
            uint8[] memory decimals,
            string[] memory tokenNames,
            string[] memory tokenSymbols,
            StreamDetails[] memory details
        )
    {
        uint256 length = hashes.length;
        details = new StreamDetails[](length);
        availableAmounts = new uint256[](length);
        decimals = new uint8[](length);
        tokenNames = new string[](length);
        tokenSymbols = new string[](length);

        for (uint256 i = 0; i < length; i++) {
            details[i] = streamDetails[hashes[i]];
            availableAmounts[i] = getAvailable(details[i].token, details[i].streamer, details[i].recipient);

            // Getting the ERC20 token details
            IERC20Metadata token = IERC20Metadata(details[i].token);
            decimals[i] = token.decimals();
            tokenNames[i] = token.name();
            tokenSymbols[i] = token.symbol();
        }

        return (availableAmounts, decimals, tokenNames, tokenSymbols, details);
    }

    function getStreamable(
        bytes32[] calldata hashes
    )
        public
        view
        returns (bool[] memory canStream, uint256[] memory balances, uint256[] memory allowances)
    {
        uint256 length = hashes.length;
        canStream = new bool[](length);
        balances = new uint256[](length);
        allowances = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            StreamDetails storage details = streamDetails[hashes[i]];
            require(details.streamer != address(0), "Stream does not exist");
            uint256 amount = getAvailable(details.token, details.streamer, details.recipient);
            balances[i] = IERC20(details.token).balanceOf(details.streamer);
            allowances[i] = IERC20(details.token).allowance(details.streamer, address(this));
            canStream[i] =
                amount + (amount * fee) / 1000 <= balances[i] && amount + (amount * fee) / 1000 <= allowances[i];
        }

        return (canStream, balances, allowances);
    }

    function batchComputeHash(
        address[] calldata streamers,
        address[] calldata tokens,
        address[] calldata recipients
    )
        public
        pure
        returns (bytes32[] memory)
    {
        require(streamers.length == tokens.length && tokens.length == recipients.length, "Input arrays length mismatch");
        uint256 length = streamers.length;
        bytes32[] memory hashes = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            hashes[i] = computeHash(streamers[i], tokens[i], recipients[i]);
        }
        return hashes;
    }

    function viewStreamerAllowances(address streamer) public view returns (bytes32[] memory) {
        return streamDetailsByStreamer[streamer];
    }

    function viewRecipientAllowances(address recipient) public view returns (bytes32[] memory) {
        return streamDetailsByRecipient[recipient];
    }

    function setFee(uint256 _fee, address newFeeAddress) public {
        require(msg.sender == feeAddress, "You are not the owner");
        fee = _fee <= 50 ? _fee : 50;
        feeAddress = newFeeAddress != address(0) ? payable(newFeeAddress) : feeAddress;
    }
}
