// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

library Validation {
    error selfCall();

    function notThis(address input) internal view {
        require(input != address(this), selfCall());
    }
}
