// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

import {IMulticall} from "../interfaces/IMulticall.sol";

abstract contract Multicall is IMulticall {
    function multicall(bytes[] calldata data) public override returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i; i != data.length; ++i) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(result, 0x20), mload(result))
                }
            }
            results[i] = result;
        }
    }
}
