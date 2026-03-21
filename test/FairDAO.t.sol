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

        claim = new FairClaim(address(fair), payable(address(amm)), merkleRoot, 0, 0, owner);

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

    function test_Claim_WithInviteHappyPath() public {
        uint256 inviterKey = 0xabc123;
        uint256 inviteeKey = 0xdef456;
        address inviter = vm.addr(inviterKey);
        address invitee = vm.addr(inviteeKey);

        vm.startPrank(owner);
        FAIR testFair = new FAIR(owner);
        FairAMM testAmm = new FairAMM(address(testFair), owner, owner);

        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(inviter))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(invitee))));
        bytes32 leaf3 = keccak256(bytes.concat(keccak256(abi.encode(user1))));

        bytes32 testRoot = _hashPair(_hashPair(leaf1, leaf2), leaf3);

        FairClaim testClaim = new FairClaim(address(testFair), payable(address(testAmm)), testRoot, 0, 0, owner);

        testFair.setAMM(address(testAmm));
        testFair.setClaimContract(address(testClaim));
        testAmm.setClaimContract(address(testClaim));
        vm.stopPrank();

        vm.deal(owner, 10 ether);
        vm.prank(owner);
        testAmm.donate{value: 1 ether}();

        bytes32[] memory inviterProof = new bytes32[](2);
        inviterProof[0] = leaf2;
        inviterProof[1] = leaf3;

        vm.prank(inviter);
        testClaim.claim(inviterProof);

        assertEq(testClaim.inviterOf(inviter), address(0));
        assertEq(testClaim.hasClaimed(inviter), true);

        bytes32[] memory inviteeProof = new bytes32[](2);
        inviteeProof[0] = leaf1;
        inviteeProof[1] = leaf3;

        uint256 deadline = block.timestamp + 1 hours;
        uint256 slotIndex = 0;

        bytes32 digest = _hashTypedDataV4(
            address(testClaim),
            keccak256(
                abi.encode(
                    testClaim.INVITE_MESSAGE_TYPEHASH(),
                    inviter,
                    invitee,
                    address(testClaim),
                    block.chainid,
                    slotIndex,
                    deadline
                )
            )
        );

        bytes memory sigInviter = _sign(digest, inviterKey);
        bytes memory sigInvitee = _sign(digest, inviteeKey);

        vm.prank(invitee);
        testClaim.claimWithInvite(inviteeProof, inviter, slotIndex, sigInviter, sigInvitee, deadline);

        assertEq(testClaim.hasClaimed(invitee), true);
        assertEq(testClaim.inviterOf(invitee), inviter);
        assertEq(testFair.balanceOf(invitee), testClaim.CLAIMANT_SHARE());
        assertEq(testFair.balanceOf(inviter), testClaim.CLAIMANT_SHARE() + testClaim.REFERRAL_REWARD_PER_LEVEL());
    }

    function test_Claim_RevertsWhenWhitelistNotSet() public {
        vm.startPrank(owner);
        FairClaim emptyClaim = new FairClaim(address(fair), payable(address(amm)), bytes32(0), 0, 0, owner);
        vm.stopPrank();

        vm.deal(owner, 10 ether);
        vm.prank(owner);
        amm.donate{value: 1 ether}();

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = bytes32(0);

        vm.prank(user1);
        vm.expectRevert(FairClaim.WhitelistNotSet.selector);
        emptyClaim.claim(proof);
    }

    function test_Claim_MultiLevelReferralRewards() public {
        uint256 key0 = 0xabc123;
        uint256 key1 = 0xabc124;
        uint256 key2 = 0xabc125;
        address user0 = vm.addr(key0);
        address user1 = vm.addr(key1);
        address user2 = vm.addr(key2);

        vm.startPrank(owner);
        FAIR testFair = new FAIR(owner);
        FairAMM testAmm = new FairAMM(address(testFair), owner, owner);

        bytes32 leaf0 = keccak256(bytes.concat(keccak256(abi.encode(user0))));
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2))));

        bytes32 testRoot = _hashPair(_hashPair(leaf0, leaf1), leaf2);

        FairClaim testClaim = new FairClaim(address(testFair), payable(address(testAmm)), testRoot, 0, 0, owner);

        testFair.setAMM(address(testAmm));
        testFair.setClaimContract(address(testClaim));
        testAmm.setClaimContract(address(testClaim));
        vm.stopPrank();

        vm.deal(owner, 10 ether);
        vm.prank(owner);
        testAmm.donate{value: 1 ether}();

        bytes32[] memory proof0 = new bytes32[](2);
        proof0[0] = leaf1;
        proof0[1] = leaf2;
        vm.prank(user0);
        testClaim.claim(proof0);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 slotIndex0 = 0;

        bytes32 digest0 = _hashTypedDataV4(
            address(testClaim),
            keccak256(
                abi.encode(
                    testClaim.INVITE_MESSAGE_TYPEHASH(),
                    user0,
                    user1,
                    address(testClaim),
                    block.chainid,
                    slotIndex0,
                    deadline
                )
            )
        );

        bytes memory sigInviter0 = _sign(digest0, key0);
        bytes memory sigInvitee0 = _sign(digest0, key1);

        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = leaf0;
        proof1[1] = leaf2;

        vm.prank(user1);
        testClaim.claimWithInvite(proof1, user0, slotIndex0, sigInviter0, sigInvitee0, deadline);

        uint256 slotIndex1 = 0;

        bytes32 digest1 = _hashTypedDataV4(
            address(testClaim),
            keccak256(
                abi.encode(
                    testClaim.INVITE_MESSAGE_TYPEHASH(),
                    user1,
                    user2,
                    address(testClaim),
                    block.chainid,
                    slotIndex1,
                    deadline
                )
            )
        );

        bytes memory sigInviter1 = _sign(digest1, key1);
        bytes memory sigInvitee1 = _sign(digest1, key2);

        bytes32[] memory proof2 = new bytes32[](1);
        proof2[0] = _hashPair(leaf0, leaf1);

        vm.prank(user2);
        testClaim.claimWithInvite(proof2, user1, slotIndex1, sigInviter1, sigInvitee1, deadline);

        assertEq(testFair.balanceOf(user2), testClaim.CLAIMANT_SHARE());
        assertEq(testFair.balanceOf(user1), testClaim.CLAIMANT_SHARE() + 1 * 1e18);
        assertEq(testFair.balanceOf(user0), testClaim.CLAIMANT_SHARE() + 2 * 1e18);
    }

    function test_Claim_ClaimWindowValidation() public {
        vm.startPrank(owner);
        FAIR windowFair = new FAIR(owner);
        FairAMM windowAmm = new FairAMM(address(windowFair), owner, owner);

        bytes32 wLeaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1))));
        bytes32 wLeaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2))));
        bytes32 wLeaf3 = keccak256(bytes.concat(keccak256(abi.encode(user3))));

        bytes32 windowRoot = _hashPair(_hashPair(wLeaf1, wLeaf2), wLeaf3);

        FairClaim windowClaim = new FairClaim(
            address(windowFair),
            payable(address(windowAmm)),
            windowRoot,
            block.timestamp + 100,
            block.timestamp + 1000,
            owner
        );

        windowFair.setAMM(address(windowAmm));
        windowFair.setClaimContract(address(windowClaim));
        windowAmm.setClaimContract(address(windowClaim));
        vm.stopPrank();

        vm.deal(owner, 10 ether);
        vm.prank(owner);
        windowAmm.donate{value: 1 ether}();

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = wLeaf2;
        proof[1] = wLeaf3;

        vm.prank(user1);
        vm.expectRevert(FairClaim.ClaimWindowNotOpen.selector);
        windowClaim.claim(proof);

        vm.warp(block.timestamp + 100);

        vm.prank(user1);
        windowClaim.claim(proof);
        assertTrue(windowClaim.hasClaimed(user1));

        vm.warp(block.timestamp + 901);

        vm.prank(user2);
        vm.expectRevert(FairClaim.ClaimWindowClosed.selector);
        bytes32[] memory proof2 = new bytes32[](2);
        proof2[0] = wLeaf1;
        proof2[1] = wLeaf3;
        windowClaim.claim(proof2);
    }

    function test_Claim_SetClaimWindowValidation() public {
        vm.prank(owner);
        vm.expectRevert(FairClaim.InvalidClaimWindow.selector);
        claim.setClaimWindow(block.timestamp + 1000, block.timestamp + 100);

        vm.prank(owner);
        claim.setClaimWindow(block.timestamp + 100, block.timestamp + 1000);
        assertEq(claim.claimWindowStart(), block.timestamp + 100);
        assertEq(claim.claimWindowEnd(), block.timestamp + 1000);
    }

    function test_Claim_GetReferralChain_Full() public {
        uint256 key0 = 0xdef123;
        uint256 key1 = 0xdef124;
        uint256 key2 = 0xdef125;
        address user0 = vm.addr(key0);
        address localUser1 = vm.addr(key1);
        address localUser2 = vm.addr(key2);

        vm.startPrank(owner);
        FAIR testFair = new FAIR(owner);
        FairAMM testAmm = new FairAMM(address(testFair), owner, owner);

        bytes32 leaf0 = keccak256(bytes.concat(keccak256(abi.encode(user0))));
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(localUser1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(localUser2))));

        bytes32 testRoot = _hashPair(_hashPair(leaf0, leaf1), leaf2);

        FairClaim testClaim = new FairClaim(address(testFair), payable(address(testAmm)), testRoot, 0, 0, owner);

        testFair.setAMM(address(testAmm));
        testFair.setClaimContract(address(testClaim));
        testAmm.setClaimContract(address(testClaim));
        vm.stopPrank();

        vm.deal(owner, 10 ether);
        vm.prank(owner);
        testAmm.donate{value: 1 ether}();

        bytes32[] memory proof0 = new bytes32[](2);
        proof0[0] = leaf1;
        proof0[1] = leaf2;
        vm.prank(user0);
        testClaim.claim(proof0);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 slotIndex0 = 0;

        bytes32 digest0 = _hashTypedDataV4(
            address(testClaim),
            keccak256(
                abi.encode(
                    testClaim.INVITE_MESSAGE_TYPEHASH(),
                    user0,
                    localUser1,
                    address(testClaim),
                    block.chainid,
                    slotIndex0,
                    deadline
                )
            )
        );

        bytes memory sigInviter0 = _sign(digest0, key0);
        bytes memory sigInvitee0 = _sign(digest0, key1);

        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = leaf0;
        proof1[1] = leaf2;

        vm.prank(localUser1);
        testClaim.claimWithInvite(proof1, user0, slotIndex0, sigInviter0, sigInvitee0, deadline);

        uint256 slotIndex1 = 0;

        bytes32 digest1 = _hashTypedDataV4(
            address(testClaim),
            keccak256(
                abi.encode(
                    testClaim.INVITE_MESSAGE_TYPEHASH(),
                    localUser1,
                    localUser2,
                    address(testClaim),
                    block.chainid,
                    slotIndex1,
                    deadline
                )
            )
        );

        bytes memory sigInviter1 = _sign(digest1, key1);
        bytes memory sigInvitee1 = _sign(digest1, key2);

        bytes32[] memory proof2 = new bytes32[](1);
        proof2[0] = _hashPair(leaf0, leaf1);

        vm.prank(localUser2);
        testClaim.claimWithInvite(proof2, localUser1, slotIndex1, sigInviter1, sigInvitee1, deadline);

        address[] memory chain = testClaim.getReferralChain(localUser2);
        assertEq(chain.length, 2);
        assertEq(chain[0], localUser1);
        assertEq(chain[1], user0);
    }

    function _hashTypedDataV4(address claimingContract, bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(claimingContract), structHash));
    }

    function _domainSeparatorV4(address claimingContract) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("FairDAO Claim")),
                keccak256(bytes("1")),
                block.chainid,
                claimingContract
            )
        );
    }

    function _sign(bytes32 digest, uint256 privateKey) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
