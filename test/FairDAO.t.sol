// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FAIR} from "../src/FAIR.sol";
import {FairAMM} from "../src/FairAMM.sol";
import {FairClaim} from "../src/FairClaim.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract FairDAOTest is Test {
    using ECDSA for bytes32;
    
    FAIR public fair;
    FairAMM public amm;
    FairClaim public claim;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    
    bytes32 public merkleRoot;
    
    function setUp() public {
        vm.startPrank(owner);
        
        fair = new FAIR(owner);
        amm = new FairAMM(address(fair), owner, owner);
        
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2))));
        bytes32 leaf3 = keccak256(bytes.concat(keccak256(abi.encode(user3))));
        
        merkleRoot = _hashPair(_hashPair(leaf1, leaf2), leaf3);
        
        claim = new FairClaim(
            address(fair),
            payable(address(amm)),
            merkleRoot,
            0,
            0,
            owner
        );
        
        fair.setAMM(address(amm));
        fair.setClaimContract(address(claim));
        amm.setClaimContract(address(claim));
        
        vm.stopPrank();
    }
    
    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        if (a <= b) {
            return keccak256(bytes.concat(a, b));
        } else {
            return keccak256(bytes.concat(b, a));
        }
    }
    
    function test_FAIR_InitialState() public view {
        assertEq(fair.name(), "FAIR Governance Token");
        assertEq(fair.symbol(), "FAIR");
        assertEq(fair.totalSupply(), 0);
        assertEq(fair.amm(), address(amm));
        assertEq(fair.claimContract(), address(claim));
    }
    
    function test_AMM_InitialState() public view {
        assertEq(address(amm.fairToken()), address(fair));
        assertEq(amm.deployer(), owner);
        assertEq(amm.ethBalance(), 0);
        assertEq(amm.fairBalance(), 0);
        assertEq(amm.SWAP_FEE_BASIS_POINTS(), 30);
    }
    
    function test_AMM_Donate() public {
        vm.deal(user1, 10 ether);
        
        vm.startPrank(user1);
        amm.donate{value: 1 ether}();
        vm.stopPrank();
        
        assertEq(amm.ethBalance(), 1 ether);
        assertEq(address(amm).balance, 1 ether);
    }
    
    function test_AMM_DonateRevertsOnZeroAmount() public {
        vm.deal(user1, 10 ether);
        
        vm.startPrank(user1);
        vm.expectRevert(FairAMM.InvalidAmount.selector);
        amm.donate{value: 0}();
        vm.stopPrank();
    }
    
    function test_AMM_HasLiquidity() public {
        assertFalse(amm.hasLiquidity());
        
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        amm.donate{value: 1 ether}();
        
        assertTrue(amm.hasLiquidity());
    }
    
    function test_Claim_InitialState() public view {
        assertEq(claim.totalClaims(), 0);
        assertEq(claim.FAIR_PER_CLAIM(), 100 * 1e18);
        assertEq(claim.CLAIMANT_SHARE(), 90 * 1e18);
        assertEq(claim.BOOTSTRAP_COUNT(), 100);
    }
    
    function test_Claim_RevertsWithNoLiquidity() public {
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2))));
        
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = keccak256(bytes.concat(keccak256(abi.encode(user3))));
        
        vm.prank(user1);
        vm.expectRevert(FairClaim.NoLiquidity.selector);
        claim.claim(proof);
    }
    
    function test_Claim_RevertsWithInvalidProof() public {
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        amm.donate{value: 1 ether}();
        
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(0);
        
        vm.prank(user1);
        vm.expectRevert(FairClaim.InvalidProof.selector);
        claim.claim(proof);
    }
    
    function test_Claim_IsBootstrapPhase() public view {
        assertTrue(claim.isBootstrapPhase());
    }
    
    function test_AMM_GetAmountOutNoLiquidity() public view {
        uint256 amountOut = amm.getAmountOut(true, 0.1 ether);
        assertEq(amountOut, 0);
    }
    
    function test_Fair_MintUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert(FAIR.Unauthorized.selector);
        fair.mint(user1, 100);
    }
    
    function test_Fair_Burn() public {
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        amm.donate{value: 1 ether}();
        
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2))));
        
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = keccak256(bytes.concat(keccak256(abi.encode(user3))));
        
        vm.prank(user1);
        claim.claim(proof);
        
        uint256 balance = fair.balanceOf(user1);
        assertTrue(balance > 0);
        
        vm.prank(user1);
        fair.burn(balance / 2);
        
        assertEq(fair.balanceOf(user1), balance / 2);
    }
    
    function test_AMM_ReceiveFunction() public {
        vm.deal(user1, 10 ether);
        
        (bool success,) = address(amm).call{value: 1 ether}("");
        assertTrue(success);
        
        assertEq(amm.ethBalance(), 1 ether);
    }
    
    function test_AMM_SwapEthForFair() public {
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        amm.donate{value: 1 ether}();
        
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2))));
        
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = keccak256(bytes.concat(keccak256(abi.encode(user3))));
        
        vm.prank(user1);
        claim.claim(proof);
        
        uint256 fairBalanceBefore = fair.balanceOf(user1);
        assertTrue(fairBalanceBefore > 0);
        
        vm.deal(user2, 10 ether);
        vm.startPrank(user2);
        
        uint256 amountOut = amm.getAmountOut(true, 0.1 ether);
        assertTrue(amountOut > 0);
        
        uint256 actualOut = amm.swapEthForFair{value: 0.1 ether}(amountOut);
        assertEq(actualOut, amountOut);
        assertEq(fair.balanceOf(user2), amountOut);
        vm.stopPrank();
    }
    
    function test_AMM_SwapFairForEth() public {
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        amm.donate{value: 1 ether}();
        
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2))));
        
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = keccak256(bytes.concat(keccak256(abi.encode(user3))));
        
        vm.prank(user1);
        claim.claim(proof);
        
        uint256 fairBalanceUser1 = fair.balanceOf(user1);
        assertTrue(fairBalanceUser1 > 0);
        
        vm.deal(user2, 10 ether);
        vm.startPrank(user2);
        uint256 fairAmount = amm.getAmountOut(true, 0.1 ether);
        amm.swapEthForFair{value: 0.1 ether}(fairAmount);
        vm.stopPrank();
        
        uint256 ethBalanceBefore = user2.balance;
        
        vm.startPrank(user2);
        fair.approve(address(amm), fairAmount);
        
        uint256 ethOut = amm.getAmountOut(false, fairAmount);
        assertTrue(ethOut > 0);
        
        uint256 actualOut = amm.swapFairForEth(fairAmount, ethOut);
        assertEq(actualOut, ethOut);
        assertEq(user2.balance, ethBalanceBefore + ethOut);
        vm.stopPrank();
    }
    
    function test_AMM_FeeDistributionCorrect() public {
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        amm.donate{value: 1 ether}();
        
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2))));
        
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = keccak256(bytes.concat(keccak256(abi.encode(user3))));
        
        vm.prank(user1);
        claim.claim(proof);
        
        vm.deal(user2, 10 ether);
        vm.prank(user2);
        amm.swapEthForFair{value: 0.1 ether}(0);
        
        uint256 trackedEth = amm.ethBalance();
        uint256 actualEth = address(amm).balance;
        
        assertEq(trackedEth, actualEth, "ETH balance mismatch - fee not properly distributed");
    }
    
    function test_AMM_RescueETH_RevertsWhenExceedsExcess() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        amm.donate{value: 1 ether}();
        
        vm.prank(owner);
        vm.expectRevert("Cannot rescue tracked ETH");
        amm.rescueETH(0.1 ether);
    }
    
    function test_Claim_RevertsWithInvalidSlotIndex() public {
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        amm.donate{value: 1 ether}();
        
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2))));
        
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaf2;
        proof[1] = keccak256(bytes.concat(keccak256(abi.encode(user3))));
        
        vm.prank(user1);
        claim.claim(proof);
        
        bytes32[] memory proof2 = new bytes32[](2);
        proof2[0] = leaf1;
        proof2[1] = keccak256(bytes.concat(keccak256(abi.encode(user3))));
        
        vm.prank(user2);
        vm.expectRevert(FairClaim.InvalidSlotIndex.selector);
        claim.claimWithInvite(proof2, user1, 100, "", "", block.timestamp + 1 hours);
    }
}
