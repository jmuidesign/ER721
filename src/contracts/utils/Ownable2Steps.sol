// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

abstract contract Ownable2Steps {
    error NotOwner();
    error NotPendingOwner();

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
