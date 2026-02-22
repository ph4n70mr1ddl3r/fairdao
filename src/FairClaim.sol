// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./FAIR.sol";
import "./FairAMM.sol";

contract FairClaim is EIP712, ReentrancyGuard, Ownable, Pausable {
    using ECDSA for bytes32;
    
    FAIR public immutable fairToken;
    FairAMM public immutable amm;
    bytes32 public immutable whitelistRoot;
    
    uint256 public constant FAIR_PER_CLAIM = 100 * 1e18;
    uint256 public constant CLAIMANT_SHARE = 90 * 1e18;
    uint256 public constant REFERRAL_BUDGET = 4 * 1e18;
    uint256 public constant AMM_BASE_SHARE = 6 * 1e18;
    uint256 public constant BOOTSTRAP_COUNT = 100;
    uint256 public constant INVITE_SLOTS_PER_MEMBER = 4;
    uint256 public constant MAX_REFERRAL_LEVELS = 4;
    uint256 public constant REFERRAL_REWARD_PER_LEVEL = 1 * 1e18;
    uint256 public constant MAX_PROOF_LENGTH = 32;
    
    uint256 public totalClaims;
    uint256 public claimWindowStart;
    uint256 public claimWindowEnd;
    
    mapping(address => bool) public hasClaimed;
    mapping(address => address) public inviterOf;
    mapping(address => uint256) public inviteSlotsUsed;
    mapping(bytes32 => bool) public usedInvitePairs;
    mapping(address => mapping(uint256 => bool)) public usedSlotIndex;
    
    event Claimed(address indexed claimant, address indexed inviter, uint256 claimantAmount, uint256 ammAmount);
    event ReferralReward(address indexed recipient, address indexed claimant, uint256 amount, uint8 level);
    event BootstrapClaim(address indexed claimant);
    event ClaimWindowSet(uint256 start, uint256 end);
    
    bytes32 public constant INVITE_MESSAGE_TYPEHASH = keccak256(
        "InviteMessage(address inviter,address invitee,address claimContract,uint256 chainId,uint256 slotIndex,uint256 deadline)"
    );
    
    struct InviteMessage {
        address inviter;
        address invitee;
        address claimContract;
        uint256 chainId;
        uint256 slotIndex;
        uint256 deadline;
    }
    
    error AlreadyClaimed();
    error InvalidProof();
    error NoLiquidity();
    error InviteExpired();
    error InviteAlreadyUsed();
    error SlotAlreadyUsed();
    error NoInviteSlots();
    error InvalidSignature();
    error InvalidSignatureLength();
    error ClaimWindowNotOpen();
    error ClaimWindowClosed();
    error InvalidInviter();
    error InvalidSlotIndex();
    error ZeroAddress();
    
    constructor(
        address _fairToken,
        address payable _amm,
        bytes32 _whitelistRoot,
        uint256 _claimWindowStart,
        uint256 _claimWindowEnd,
        address initialOwner
    ) EIP712("FairDAO Claim", "1") Ownable(initialOwner) {
        if (_fairToken == address(0) || _amm == address(0) || initialOwner == address(0)) revert ZeroAddress();
        fairToken = FAIR(_fairToken);
        amm = FairAMM(_amm);
        whitelistRoot = _whitelistRoot;
        claimWindowStart = _claimWindowStart;
        claimWindowEnd = _claimWindowEnd;
    }
    
    function setClaimWindow(uint256 _start, uint256 _end) external onlyOwner {
        claimWindowStart = _start;
        claimWindowEnd = _end;
        emit ClaimWindowSet(_start, _end);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function claim(bytes32[] calldata merkleProof) external nonReentrant whenNotPaused {
        _validateClaimWindow();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (merkleProof.length > MAX_PROOF_LENGTH) revert InvalidProof();
        if (!_verifyMerkleProof(merkleProof, msg.sender)) revert InvalidProof();
        if (!amm.hasLiquidity()) revert NoLiquidity();
        
        bool isBootstrap = totalClaims < BOOTSTRAP_COUNT;
        
        hasClaimed[msg.sender] = true;
        totalClaims++;
        
        if (isBootstrap) {
            inviterOf[msg.sender] = address(0);
            emit BootstrapClaim(msg.sender);
        }
        
        uint256 ammDonation = AMM_BASE_SHARE + REFERRAL_BUDGET;
        
        fairToken.mint(msg.sender, CLAIMANT_SHARE);
        fairToken.mint(address(amm), ammDonation);
        amm.addFairLiquidity(ammDonation);
        
        emit Claimed(msg.sender, address(0), CLAIMANT_SHARE, ammDonation);
    }
    
    function claimWithInvite(
        bytes32[] calldata merkleProof,
        address inviter,
        uint256 slotIndex,
        bytes calldata sigInviter,
        bytes calldata sigInvitee,
        uint256 deadline
    ) external nonReentrant whenNotPaused {
        _validateClaimWindow();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (merkleProof.length > MAX_PROOF_LENGTH) revert InvalidProof();
        if (!_verifyMerkleProof(merkleProof, msg.sender)) revert InvalidProof();
        if (!amm.hasLiquidity()) revert NoLiquidity();
        if (deadline < block.timestamp) revert InviteExpired();
        if (inviter == address(0)) revert InvalidInviter();
        if (!hasClaimed[inviter]) revert InvalidInviter();
        if (slotIndex >= INVITE_SLOTS_PER_MEMBER) revert InvalidSlotIndex();
        if (inviteSlotsUsed[inviter] >= INVITE_SLOTS_PER_MEMBER) revert NoInviteSlots();
        if (sigInviter.length != 65 || sigInvitee.length != 65) revert InvalidSignatureLength();
        
        bytes32 invitePairHash = keccak256(abi.encodePacked(inviter, msg.sender, slotIndex));
        if (usedInvitePairs[invitePairHash]) revert InviteAlreadyUsed();
        if (usedSlotIndex[inviter][slotIndex]) revert SlotAlreadyUsed();
        
        InviteMessage memory message = InviteMessage({
            inviter: inviter,
            invitee: msg.sender,
            claimContract: address(this),
            chainId: block.chainid,
            slotIndex: slotIndex,
            deadline: deadline
        });
        
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            INVITE_MESSAGE_TYPEHASH,
            message.inviter,
            message.invitee,
            message.claimContract,
            message.chainId,
            message.slotIndex,
            message.deadline
        )));
        
        address signerInviter = digest.recover(sigInviter);
        address signerInvitee = digest.recover(sigInvitee);
        
        if (signerInviter != inviter) revert InvalidSignature();
        if (signerInvitee != msg.sender) revert InvalidSignature();
        
        usedInvitePairs[invitePairHash] = true;
        usedSlotIndex[inviter][slotIndex] = true;
        inviteSlotsUsed[inviter]++;
        hasClaimed[msg.sender] = true;
        inviterOf[msg.sender] = inviter;
        totalClaims++;
        
        uint256 referralUsed = _distributeReferralRewards(inviter, msg.sender);
        uint256 ammDonation = AMM_BASE_SHARE + (REFERRAL_BUDGET - referralUsed);
        
        fairToken.mint(msg.sender, CLAIMANT_SHARE);
        fairToken.mint(address(amm), ammDonation);
        amm.addFairLiquidity(ammDonation);
        
        emit Claimed(msg.sender, inviter, CLAIMANT_SHARE, ammDonation);
    }
    
    function _distributeReferralRewards(address inviter, address claimant) internal returns (uint256 totalDistributed) {
        address currentInviter = inviter;
        
        for (uint8 level = 0; level < MAX_REFERRAL_LEVELS && currentInviter != address(0); level++) {
            fairToken.mint(currentInviter, REFERRAL_REWARD_PER_LEVEL);
            emit ReferralReward(currentInviter, claimant, REFERRAL_REWARD_PER_LEVEL, level);
            totalDistributed += REFERRAL_REWARD_PER_LEVEL;
            currentInviter = inviterOf[currentInviter];
        }
    }
    
    function _validateClaimWindow() internal view {
        if (claimWindowStart > 0 && block.timestamp < claimWindowStart) revert ClaimWindowNotOpen();
        if (claimWindowEnd > 0 && block.timestamp > claimWindowEnd) revert ClaimWindowClosed();
    }
    
    function _verifyMerkleProof(bytes32[] calldata proof, address account) internal view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account))));
        return MerkleProof.verify(proof, whitelistRoot, leaf);
    }

    function isBootstrapPhase() external view returns (bool) {
        return totalClaims < BOOTSTRAP_COUNT;
    }

    function remainingInviteSlots(address user) external view returns (uint256) {
        if (!hasClaimed[user]) return 0;
        return INVITE_SLOTS_PER_MEMBER - inviteSlotsUsed[user];
    }

    function getReferralChain(address account) external view returns (address[] memory) {
        uint256 depth = 0;
        address current = inviterOf[account];

        while (current != address(0) && depth < MAX_REFERRAL_LEVELS) {
            depth++;
            current = inviterOf[current];
        }

        address[] memory chain = new address[](depth);
        current = inviterOf[account];

        for (uint256 i = 0; i < depth; i++) {
            chain[i] = current;
            current = inviterOf[current];
        }

        return chain;
    }
}
