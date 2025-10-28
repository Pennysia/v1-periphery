// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.30;

import {IPayment} from "../interfaces/IPayment.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";

abstract contract Payment is IPayment {
    address public immutable market;

    constructor(address _market) {
        market = _market;
    }

    function requestToken(address from, address[] memory tokens, uint256[] memory paybackAmounts)
        external
        payable
        override
    {
        require(msg.sender == market, notMarket());
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                TransferHelper.safeTransfer(address(0), market, paybackAmounts[i]);
            } else {
                TransferHelper.safeTransferFrom(tokens[i], from, market, paybackAmounts[i]);
            }
        }
    }

    function refundNative(address to) internal {
        uint256 balance = address(this).balance;
        if (balance > 0) TransferHelper.safeTransfer(address(0), to, balance);
    }
}
