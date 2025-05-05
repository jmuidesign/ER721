// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICrowdsale} from "../../interfaces/ICrowdsale.sol";
import {ICommonErrors} from "../../interfaces/ICommonErrors.sol";

abstract contract Crowdsale is ICrowdsale, ICommonErrors {
    uint256 public immutable minimumPrice;
    uint256 public immutable endGracePeriod;

    constructor(uint256 _minimumPrice, uint256 _revealTime, uint256 _withdrawGracePeriod) {
        minimumPrice = _minimumPrice;
        endGracePeriod = _revealTime + _withdrawGracePeriod;
    }

    function _buyToken(address to, uint256 amount) internal view {
        if (to == address(0)) revert AddressZero();
        if (amount < minimumPrice) revert NotEnoughETH();
    }

    function _withdraw(address to, uint256 amount) internal {
        if (block.timestamp < endGracePeriod) revert WithdrawGracePeriodNotEnded();

        (bool success,) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
