// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {FAIR} from "../src/FAIR.sol";
import {FairAMM} from "../src/FairAMM.sol";
import {FairClaim} from "../src/FairClaim.sol";
import {FairGovernor} from "../src/FairGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title DeployFairDAO
 * @notice Deployment script for FairDAO contracts
 * @dev Uses Foundry's Script for deterministic deployment.
 *      Deployment order:
 *      1. FAIR token (owner = deployer)
 *      2. FairAMM (owner = deployer)
 *      3. FairClaim (owner = deployer)
 *      4. TimelockController (admin = deployer, then renounced)
 *      5. FairGovernor (timelock = TimelockController)
 *      6. Configure roles and transfer ownership to timelock
 */
contract DeployFairDAO is Script {
    /// @notice Placeholder whitelist root (replace with actual root)
    bytes32 public constant WHITELIST_ROOT = bytes32(0);
    /// @notice Claim window start (0 = no restriction)
    uint256 public constant CLAIM_WINDOW_START = 0;
    /// @notice Claim window end (0 = no restriction)
    uint256 public constant CLAIM_WINDOW_END = 0;

    /// @notice Voting delay in blocks (~1 day at 12s blocks)
    uint48 public constant VOTING_DELAY = 7200;
    /// @notice Voting period in blocks (~1 week at 12s blocks)
    uint32 public constant VOTING_PERIOD = 50400;
    /// @notice Minimum tokens to create proposal
    uint256 public constant PROPOSAL_THRESHOLD = 100 * 1e18;
    /// @notice Quorum numerator (4 = 4% of supply)
    uint256 public constant QUORUM_NUMERATOR = 4;
    /// @notice Timelock delay before execution
    uint256 public constant TIMELOCK_DELAY = 2 days;

    /// @notice Thrown when private key is invalid
    error InvalidPrivateKey();
    /// @notice Thrown when whitelist root is not set
    error WhitelistRootNotSet();
    /// @notice Thrown when contract setup validation fails
    error SetupValidationFailed();

    /// @dev Validates that all contract addresses are properly configured
    function _validateSetup(FAIR fair_, FairAMM amm_, FairClaim claim_) internal pure {
        if (fair_.amm() != address(amm_)) revert SetupValidationFailed();
        if (fair_.claimContract() != address(claim_)) revert SetupValidationFailed();
        if (amm_.claimContract() != address(claim_)) revert SetupValidationFailed();
    }

    /// @notice Deploys all FairDAO contracts
    /// @return fair The FAIR token contract
    /// @return amm The FairAMM contract
    /// @return claim The FairClaim contract
    /// @return governor The FairGovernor contract
    /// @return timelock The TimelockController contract
    function run() external returns (FAIR, FairAMM, FairClaim, FairGovernor, TimelockController) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) revert InvalidPrivateKey();
        if (WHITELIST_ROOT == bytes32(0)) revert WhitelistRootNotSet();
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);

        FAIR fair = new FAIR(deployer);

        FairAMM amm = new FairAMM(address(fair), deployer, deployer);

        FairClaim claim = new FairClaim(
            address(fair), payable(address(amm)), WHITELIST_ROOT, CLAIM_WINDOW_START, CLAIM_WINDOW_END, deployer
        );

        address[] memory proposers = new address[](0);

        address[] memory executors = new address[](0);

        TimelockController timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, deployer);

        FairGovernor governor =
            new FairGovernor(fair, timelock, VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD, QUORUM_NUMERATOR);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(governor));

        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        fair.setAMM(address(amm));
        fair.setClaimContract(address(claim));
        amm.setClaimContract(address(claim));

        _validateSetup(fair, amm, claim);

        fair.transferOwnership(address(timelock));
        amm.transferOwnership(address(timelock));
        claim.transferOwnership(address(timelock));

        vm.stopBroadcast();

        return (fair, amm, claim, governor, timelock);
    }
}
