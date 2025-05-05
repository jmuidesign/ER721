// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOwnable2Steps {
    error NotOwner();
    error NotPendingOwner();

    function transferOwnership(address newOwner) external;
    function acceptOwnership() external;
}
