// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {FAIR} from "../src/FAIR.sol";
import {FairAMM} from "../src/FairAMM.sol";
import {FairClaim} from "../src/FairClaim.sol";
import {FairGovernor} from "../src/FairGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployFairDAO is Script {
    bytes32 public constant WHITELIST_ROOT = bytes32(0);
    uint256 public constant CLAIM_WINDOW_START = 0;
    uint256 public constant CLAIM_WINDOW_END = 0;
    
    uint48 public constant VOTING_DELAY = 7200;
    uint32 public constant VOTING_PERIOD = 50400;
    uint256 public constant PROPOSAL_THRESHOLD = 100 * 1e18;
    uint256 public constant QUORUM_NUMERATOR = 4;
    uint256 public constant TIMELOCK_DELAY = 2 days;

    function run() external returns (FAIR, FairAMM, FairClaim, FairGovernor, TimelockController) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        address deployer = vm.addr(deployerPrivateKey);
        
        FAIR fair = new FAIR(deployer);
        
        FairAMM amm = new FairAMM(address(fair), deployer, deployer);
        
        FairClaim claim = new FairClaim(
            address(fair),
            payable(address(amm)),
            WHITELIST_ROOT,
            CLAIM_WINDOW_START,
            CLAIM_WINDOW_END,
            deployer
        );
        
        address[] memory proposers = new address[](1);
        proposers[0] = address(0);
        
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        
        TimelockController timelock = new TimelockController(
            TIMELOCK_DELAY,
            proposers,
            executors,
            deployer
        );
        
        FairGovernor governor = new FairGovernor(
            fair,
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_NUMERATOR
        );
        
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(governor));
        
        timelock.revokeRole(proposerRole, deployer);
        
        fair.setAMM(address(amm));
        fair.setClaimContract(address(claim));
        amm.setClaimContract(address(claim));
        
        vm.stopBroadcast();
        
        return (fair, amm, claim, governor, timelock);
    }
}
