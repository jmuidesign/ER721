// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../../helpers/CommonErrors.sol";

abstract contract Crowdsale {
    error InvalidRate();
    error PendingWithdraw();
    error WithdrawGracePeriodNotEnded();

    uint256 public immutable minimumPrice;
    uint256 public weiRaised;

    uint256 internal immutable withdrawGracePeriod;
    uint256 internal endGracePeriod;
    uint256 internal withdrawAmount;

    constructor(uint256 _minimumPrice, uint256 _withdrawGracePeriod) {
        minimumPrice = _minimumPrice;
        withdrawGracePeriod = _withdrawGracePeriod;
    }

    function _buyToken(address to, uint256 amount) internal {
        if (to == address(0)) revert AddressZero();
        if (amount < minimumPrice) revert NotEnoughETH();

        weiRaised += amount;
    }

    function _launchWithdraw(uint256 amount, uint256 revealTime) internal {
        if (withdrawAmount > 0) revert PendingWithdraw();

        // First withdraw starts from release time
        // Subsequent withdraws start from current time
        endGracePeriod = endGracePeriod == 0 ? revealTime + withdrawGracePeriod : block.timestamp + withdrawGracePeriod;

        withdrawAmount = amount;
    }

    function _executeWithdraw(address to) internal {
        if (block.timestamp < endGracePeriod) revert WithdrawGracePeriodNotEnded();

        (bool success,) = payable(to).call{value: withdrawAmount}("");
        if (!success) revert TransferFailed();
    }
}
