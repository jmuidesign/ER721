// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnable2Steps} from "../../interfaces/IOwnable2Steps.sol";

abstract contract Ownable2Steps is IOwnable2Steps {
    address internal owner;
    address internal pendingOwner;

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();

        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();

        owner = msg.sender;
        pendingOwner = address(0);
    }
}
