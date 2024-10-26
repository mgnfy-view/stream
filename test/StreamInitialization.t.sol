// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { GlobalHelper } from "./utils/GlobalHelper.sol";

contract StreamInitializationTest is GlobalHelper {
    function test_feeAddressInitializedCorrectly() public view {
        assertEq(stream.feeAddress(), owner);
    }

    function test_feeInitializedToZero() public view {
        assertEq(stream.fee(), 0);
    }

    function test_onlyAdminCanSetFee() public {
        uint256 newFee = 10;

        vm.startPrank(streamer);
        vm.expectRevert(bytes(YOU_ARE_NOT_THE_OWNER));
        stream.setFee(newFee, address(0));
        vm.stopPrank();
    }

    function test_setFeeLessThanFifty() public {
        uint256 newFee = 10;

        vm.startPrank(owner);
        stream.setFee(newFee, address(0));
        vm.stopPrank();

        assertEq(stream.fee(), newFee);
    }

    function test_setFeeGreaterThanFifty() public {
        uint256 newFee = 100;
        uint256 expectedFee = 50;

        vm.startPrank(owner);
        stream.setFee(newFee, address(0));
        vm.stopPrank();

        assertEq(stream.fee(), expectedFee);
    }

    function test_adminRemainsUnchangedWhenAddressZeroPassedToSetFee() public {
        uint256 newFee = 10;

        vm.startPrank(owner);
        stream.setFee(newFee, address(0));
        vm.stopPrank();

        assertEq(stream.feeAddress(), owner);
    }

    function test_adminChangesWhenNonZeroAddressPassedToSetFee() public {
        address newFeeAddress = makeAddr("newFeeAddress");

        vm.startPrank(owner);
        stream.setFee(stream.fee(), newFeeAddress);
        vm.stopPrank();

        assertEq(stream.feeAddress(), newFeeAddress);
    }
}
