// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

interface IMulticall {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}
