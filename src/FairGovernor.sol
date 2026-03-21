// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "./FAIR.sol";

/**
 * @title FairGovernor
 * @notice Governance contract for FairDAO with timelock execution
 * @dev Standard OpenZeppelin Governor with 4% quorum threshold and timelock control.
 *      Features:
 *      - Token-weighted voting via FAIR token
 *      - Configurable voting delay and period
 *      - Proposal threshold for creating proposals
 *      - Timelock control for delayed execution
 *      - Quorum based on percentage of total supply
 */
contract FairGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /// @notice The FAIR token used for voting
    FAIR public immutable fairToken;

    /// @notice Thrown when zero address is provided
    error ZeroAddress();

    /// @notice Constructor initializes the governor
    /// @param _token The FAIR token address for voting
    /// @param _timelock The timelock controller address
    /// @param initialVotingDelay Number of blocks before voting starts
    /// @param initialVotingPeriod Number of blocks for voting
    /// @param initialProposalThreshold Minimum tokens needed to propose
    /// @param quorumNumerator Numerator for quorum fraction (e.g., 4 = 4%)
    constructor(
        FAIR _token,
        TimelockController _timelock,
        uint48 initialVotingDelay,
        uint32 initialVotingPeriod,
        uint256 initialProposalThreshold,
        uint256 quorumNumerator
    )
        Governor("FairDAO Governor")
        GovernorSettings(initialVotingDelay, initialVotingPeriod, initialProposalThreshold)
        GovernorVotes(IVotes(address(_token)))
        GovernorVotesQuorumFraction(quorumNumerator)
        GovernorTimelockControl(_timelock)
    {
        if (address(_token) == address(0) || address(_timelock) == address(0)) revert ZeroAddress();
        fairToken = _token;
    }

    /// @notice Returns the voting delay in blocks
    /// @return Number of blocks before voting starts on a proposal
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    /// @notice Returns the voting period in blocks
    /// @return Number of blocks voting is open
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    /// @notice Returns the quorum for a given block number
    /// @param blockNumber The block number to query
    /// @return Minimum number of votes needed for quorum
    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    /// @notice Returns the state of a proposal
    /// @param proposalId The proposal ID to query
    /// @return Current state of the proposal
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    /// @notice Returns whether a proposal needs to be queued
    /// @param proposalId The proposal ID to query
    /// @return True if proposal needs queuing
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /// @notice Returns the proposal threshold
    /// @return Minimum tokens needed to create a proposal
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    /// @dev Internal function to execute proposal operations
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @dev Internal function to cancel a proposal
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /// @dev Returns the executor address
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    /// @dev Internal function to queue proposal operations
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }
}
