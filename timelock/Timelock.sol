// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "TimelockController.sol";

contract Timelock is TimelockController {
    // minDelay - time to wait before executing
    // proposers - list of addresses that can propose
    // executors - list of addresses that can execute
    // admin - optional account to be granted admin role; by default zero address
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}