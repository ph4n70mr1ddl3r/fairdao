// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./FAIR.sol";
import "./FairAMM.sol";

/**
 * @title FairClaim
 * @notice Whitelist-based token claiming with referral rewards
 * @dev Uses merkle proofs for whitelist verification and EIP-712 typed signature for invites.
 *      Bootstrap phase (first 100 claims) has no inviter requirement.
 *      Key features:
 *      - Merkle proof-based whitelist verification
 *      - Multi-level referral rewards (up to 4 levels)
 *      - EIP-712 typed signatures for secure invites
 *      - Claim window with start/end timestamps
 *      - Pausable for emergency situations
 */
contract FairClaim is EIP712, ReentrancyGuard, Ownable, Pausable {
    using ECDSA for bytes32;

    /// @notice The FAIR token contract
    FAIR public immutable fairToken;
    /// @notice The AMM contract
    FairAMM public immutable amm;
    /// @notice Merkle root for whitelist verification
    bytes32 public immutable whitelistRoot;

    /// @notice Total FAIR tokens distributed per claim
    uint256 public constant FAIR_PER_CLAIM = 100 * 1e18;
    /// @notice Share going to the claimant
    uint256 public constant CLAIMANT_SHARE = 90 * 1e18;
    /// @notice Budget reserved for referral rewards
    uint256 public constant REFERRAL_BUDGET = 4 * 1e18;
    /// @notice Base share going to AMM liquidity
    uint256 public constant AMM_BASE_SHARE = 6 * 1e18;
    /// @notice Number of bootstrap claims (no inviter needed)
    uint256 public constant BOOTSTRAP_COUNT = 100;
    /// @notice Number of invite slots per member
    uint256 public constant INVITE_SLOTS_PER_MEMBER = 4;
    /// @notice Maximum referral levels for rewards
    uint256 public constant MAX_REFERRAL_LEVELS = 4;
    /// @notice Reward per referral level
    uint256 public constant REFERRAL_REWARD_PER_LEVEL = 1 * 1e18;
    /// @notice Maximum merkle proof length
    uint256 public constant MAX_PROOF_LENGTH = 32;

    /// @notice Total number of claims processed
    uint256 public totalClaims;
    /// @notice Start timestamp for claim window (0 = no restriction)
    uint256 public claimWindowStart;
    /// @notice End timestamp for claim window (0 = no restriction)
    uint256 public claimWindowEnd;

    /// @notice Mapping of addresses that have claimed
    mapping(address => bool) public hasClaimed;
    /// @notice Mapping of invitee to their inviter
    mapping(address => address) public inviterOf;
    /// @notice Mapping of inviter to number of slots used
    mapping(address => uint256) public inviteSlotsUsed;
    /// @notice Mapping of used invite pair hashes
    mapping(bytes32 => bool) public usedInvitePairs;
    /// @notice Mapping of inviter to used slot indices
    mapping(address => mapping(uint256 => bool)) public usedSlotIndex;

    /// @notice Emitted on successful claim
    event Claimed(address indexed claimant, address indexed inviter, uint256 claimantAmount, uint256 ammAmount);
    /// @notice Emitted on referral reward distribution
    event ReferralReward(address indexed recipient, address indexed claimant, uint256 amount, uint8 level);
    /// @notice Emitted on bootstrap claim
    event BootstrapClaim(address indexed claimant);
    /// @notice Emitted when claim window is updated
    event ClaimWindowSet(uint256 start, uint256 end);

    /// @notice EIP-712 typehash for invite messages
    bytes32 public constant INVITE_MESSAGE_TYPEHASH = keccak256(
        "InviteMessage(address inviter,address invitee,address claimContract,uint256 chainId,uint256 slotIndex,uint256 deadline)"
    );

    /// @notice Struct for EIP-712 typed invite message
    struct InviteMessage {
        address inviter;
        address invitee;
        address claimContract;
        uint256 chainId;
        uint256 slotIndex;
        uint256 deadline;
    }

    /// @notice Thrown when address has already claimed
    error AlreadyClaimed();
    /// @notice Thrown when merkle proof is invalid
    error InvalidProof();
    /// @notice Thrown when AMM has no liquidity
    error NoLiquidity();
    /// @notice Thrown when whitelist root is not set
    error WhitelistNotSet();
    /// @notice Thrown when invite has expired
    error InviteExpired();
    /// @notice Thrown when invite pair was already used
    error InviteAlreadyUsed();
    /// @notice Thrown when slot index was already used
    error SlotAlreadyUsed();
    /// @notice Thrown when inviter has no invite slots
    error NoInviteSlots();
    /// @notice Thrown when signature is invalid
    error InvalidSignature();
    /// @notice Thrown when signature length is invalid
    error InvalidSignatureLength();
    /// @notice Thrown when claim window is not open
    error ClaimWindowNotOpen();
    /// @notice Thrown when claim window is closed
    error ClaimWindowClosed();
    /// @notice Thrown when inviter is invalid
    error InvalidInviter();
    /// @notice Thrown when slot index is invalid
    error InvalidSlotIndex();
    /// @notice Thrown when zero address is provided
    error ZeroAddress();
    /// @notice Thrown when trying to self-invite
    error SelfInvite();
    /// @notice Thrown when claim window parameters are invalid
    error InvalidClaimWindow();

    /// @notice Constructor initializes the claim contract
    /// @param _fairToken Address of the FAIR token contract
    /// @param _amm Address of the AMM contract
    /// @param _whitelistRoot Merkle root for whitelist verification
    /// @param _claimWindowStart Start timestamp for claim window (0 = no restriction)
    /// @param _claimWindowEnd End timestamp for claim window (0 = no restriction)
    /// @param initialOwner Address that will own the contract
    constructor(
        address _fairToken,
        address payable _amm,
        bytes32 _whitelistRoot,
        uint256 _claimWindowStart,
        uint256 _claimWindowEnd,
        address initialOwner
    ) EIP712("FairDAO Claim", "1") Ownable(initialOwner) {
        if (_fairToken == address(0) || _amm == address(0) || initialOwner == address(0)) {
            revert ZeroAddress();
        }
        fairToken = FAIR(_fairToken);
        amm = FairAMM(_amm);
        whitelistRoot = _whitelistRoot;
        claimWindowStart = _claimWindowStart;
        claimWindowEnd = _claimWindowEnd;
    }

    /// @notice Set the claim window period
    /// @param _start Start timestamp (0 = no restriction)
    /// @param _end End timestamp (0 = no restriction)
    function setClaimWindow(uint256 _start, uint256 _end) external onlyOwner {
        if (_start != 0 && _end != 0 && _start >= _end) revert InvalidClaimWindow();
        claimWindowStart = _start;
        claimWindowEnd = _end;
        emit ClaimWindowSet(_start, _end);
    }

    /// @notice Pause all claim operations
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause claim operations
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Claim FAIR tokens as a bootstrap participant (first 100)
    /// @param merkleProof Merkle proof proving whitelist eligibility
    function claim(bytes32[] calldata merkleProof) external nonReentrant whenNotPaused {
        _validateClaimWindow();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (merkleProof.length > MAX_PROOF_LENGTH) revert InvalidProof();
        if (!_verifyMerkleProof(merkleProof, msg.sender)) revert InvalidProof();
        if (!amm.hasLiquidity()) revert NoLiquidity();

        bool isBootstrap = totalClaims < BOOTSTRAP_COUNT;

        hasClaimed[msg.sender] = true;
        unchecked {
            totalClaims++;
        }

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

    /// @notice Claim FAIR tokens with an invitation from an existing member
    /// @param merkleProof Merkle proof proving whitelist eligibility
    /// @param inviter Address of the member who invited you
    /// @param slotIndex Invite slot index used (0-3)
    /// @param sigInviter Signature from the inviter
    /// @param sigInvitee Signature from the invitee (caller)
    /// @param deadline Expiration timestamp for the invitation
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
        if (inviter == msg.sender) revert SelfInvite();
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

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    INVITE_MESSAGE_TYPEHASH,
                    message.inviter,
                    message.invitee,
                    message.claimContract,
                    message.chainId,
                    message.slotIndex,
                    message.deadline
                )
            )
        );

        address signerInviter = digest.recover(sigInviter);
        address signerInvitee = digest.recover(sigInvitee);

        if (signerInviter != inviter) revert InvalidSignature();
        if (signerInvitee != msg.sender) revert InvalidSignature();

        usedInvitePairs[invitePairHash] = true;
        usedSlotIndex[inviter][slotIndex] = true;
        unchecked {
            inviteSlotsUsed[inviter]++;
        }
        hasClaimed[msg.sender] = true;
        inviterOf[msg.sender] = inviter;
        unchecked {
            totalClaims++;
        }

        uint256 referralUsed = _distributeReferralRewards(inviter, msg.sender);
        uint256 ammDonation = AMM_BASE_SHARE + (REFERRAL_BUDGET - referralUsed);

        fairToken.mint(msg.sender, CLAIMANT_SHARE);
        fairToken.mint(address(amm), ammDonation);
        amm.addFairLiquidity(ammDonation);

        emit Claimed(msg.sender, inviter, CLAIMANT_SHARE, ammDonation);
    }

    /// @dev Distributes referral rewards up the invite chain (max 4 levels)
    /// @param inviter The direct inviter of the claimant
    /// @param claimant The address that just claimed
    /// @return totalDistributed Total FAIR tokens distributed as referral rewards
    function _distributeReferralRewards(address inviter, address claimant) internal returns (uint256 totalDistributed) {
        address currentInviter = inviter;

        for (uint8 level = 0; level < MAX_REFERRAL_LEVELS && currentInviter != address(0);) {
            fairToken.mint(currentInviter, REFERRAL_REWARD_PER_LEVEL);
            emit ReferralReward(currentInviter, claimant, REFERRAL_REWARD_PER_LEVEL, level);
            unchecked {
                totalDistributed += REFERRAL_REWARD_PER_LEVEL;
                ++level;
            }
            currentInviter = inviterOf[currentInviter];
        }
    }

    /// @dev Validates that the current timestamp is within the claim window
    function _validateClaimWindow() internal view {
        if (claimWindowStart > 0 && block.timestamp < claimWindowStart) revert ClaimWindowNotOpen();
        if (claimWindowEnd > 0 && block.timestamp > claimWindowEnd) revert ClaimWindowClosed();
    }

    /// @dev Verifies a merkle proof for whitelist eligibility
    /// @param proof The merkle proof
    /// @param account The address to verify
    /// @return True if the proof is valid
    function _verifyMerkleProof(bytes32[] calldata proof, address account) internal view returns (bool) {
        if (whitelistRoot == bytes32(0)) revert WhitelistNotSet();
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account))));
        return MerkleProof.verify(proof, whitelistRoot, leaf);
    }

    /// @notice Check if currently in bootstrap phase (first 100 claims)
    /// @return True if in bootstrap phase
    function isBootstrapPhase() external view returns (bool) {
        return totalClaims < BOOTSTRAP_COUNT;
    }

    /// @notice Get remaining invite slots for a user
    /// @param user Address to check
    /// @return Number of remaining invite slots
    function remainingInviteSlots(address user) external view returns (uint256) {
        if (!hasClaimed[user]) return 0;
        return INVITE_SLOTS_PER_MEMBER - inviteSlotsUsed[user];
    }

    /// @notice Get the referral chain for an account
    /// @param account Address to get chain for
    /// @return Array of inviter addresses from level 1 to max depth
    function getReferralChain(address account) external view returns (address[] memory) {
        address[MAX_REFERRAL_LEVELS] memory tempChain;
        uint256 depth = 0;
        address current = inviterOf[account];

        while (current != address(0) && depth < MAX_REFERRAL_LEVELS) {
            tempChain[depth] = current;
            depth++;
            current = inviterOf[current];
        }

        address[] memory chain = new address[](depth);
        for (uint256 i = 0; i < depth;) {
            chain[i] = tempChain[i];
            unchecked { ++i; }
        }

        return chain;
    }
}
