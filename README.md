# FairDAO: Fair Token Distribution and Permanent Liquidity

**Version 0.1 (draft)**  
**Date: November 22, 2025**  
**Authors: ph4n70mr1ddl3r**  

---

## Abstract

FairDAO is an innovative Ethereum-based protocol designed to enable fair, Sybil-resistant token launches with built-in permanent liquidity and sustainable developer incentives. At its core, FairDAO leverages a historical whitelist of approximately 64.8 million Ethereum addresses that have demonstrated meaningful on-chain activity (paying at least 0.004 ETH in gas fees up to block 23,000,000, circa mid-2025). This whitelist, analyzed for unique ownership, is estimated to represent 12–25 million distinct entities, likely corresponding to 10–20 million human owners.

The FAIR token is distributed via a one-per-address claim mechanism, minting a fixed 100 FAIR per successful claim: 90 to the claimant, up to 4 to referrers in a bounded invite forest, and at least 6 to a non-withdrawable FAIR/ETH constant-product automated market maker (AMM). Invitations require mutual signatures to prevent hijacking, and claims are gated on the AMM holding positive ETH to ensure balanced liquidity.

The AMM charges a 0.3% swap fee, split equally between pool growth, FAIR burns (deflationary pressure), and a capped ETH stream to the deployer for ongoing development. Governance allows parameter tuning without compromising core invariants like non-withdrawable liquidity or fixed emissions.

This whitepaper expands on prior drafts by incorporating 2025 research on Ethereum clustering, Layer-2 dynamics, and Sybil resistance. It includes enhancements such as optional ZK proofs for uniqueness, dynamic invite adjustments, phased claiming, and economic modeling to improve viability. FairDAO aims to set a new standard for equitable, transparent token launches in a post-2025 crypto ecosystem characterized by institutional adoption and scaling solutions.

---

## 1. Introduction

### 1.1 Motivation

The cryptocurrency space has seen numerous token launches marred by issues such as heavy premines, insider allocations, opaque private sales, illiquid markets prone to manipulation, and Sybil attacks via airdrop farming. These problems undermine trust, concentrate supply, and hinder broad adoption.

FairDAO addresses these by integrating distribution, liquidity provision, and incentives into a single on-chain protocol. Key principles include:
- **Zero Premine**: No initial allocations to teams, VCs, or founders.
- **Broad, Anti-Sybil Distribution**: Based on a fixed, historical Ethereum whitelist to prevent retroactive farming.
- **Permanent Liquidity**: A non-withdrawable FAIR/ETH AMM that grows with every claim and trade.
- **Bounded Referrals**: A mutual-signature invite system to encourage organic growth while limiting Sybils.
- **Sustainable Incentives**: Transparent fees for developers and deflationary burns.
- **Governance with Guardrails**: Parameter adjustments without power to drain pools or seize assets.

By November 2025, with Ethereum's post-Dencun upgrades reducing fees and Layer-2s handling ~80% of activity (per a16z reports), FairDAO is positioned to leverage a mature ecosystem for wide-reaching, egalitarian tokenomics.

### 1.2 Key Innovations

- **Ex-Post Whitelist**: Uses past gas expenditure as a proxy for genuine activity, estimated to reach 10–20 million humans.
- **Fixed Emissions per Claim**: 100 FAIR always, decoupling supply from time or complexity.
- **Invite Forest with Mutual Signatures**: Caps invites at 4 per member, rewards up to 4 levels, and requires bilateral consent.
- **Fee-Split AMM**: 0.3% swaps fund liquidity depth, burns, and dev incentives.
- **Enhancements for Viability**: Optional ZK uniqueness proofs, dynamic Sybil penalties, and phased rollout.

### 1.3 Scope and Assumptions

This whitepaper assumes Ethereum mainnet deployment, with potential Layer-2 extensions. It does not enforce real-world identity but provides address-level Sybil resistance. Economic models assume rational actors; full simulations are recommended pre-launch.

---

## 2. Background: Ethereum Whitelist and Ownership Estimation

### 2.1 Whitelist Construction

FairDAO's eligibility is based on a static whitelist of 64,846,015 Ethereum externally owned accounts (EOAs) that paid ≥0.004 ETH in gas fees from block 0 (July 2015) to block 23,000,000 (circa June 2025). This threshold filters dust accounts while ensuring non-trivial economic commitment.

Key features:
- **Historical Cutoff**: Ex-post definition prevents farming.
- **EOA Focus**: Minimal contract wallets (<1%).
- **Merkle Root**: Stored on-chain for efficient proofs; off-chain infrastructure provides proofs.

### 2.2 Ownership Analysis

Drawing from 2025 studies (e.g., Meier et al., Bonifazi et al.), address clustering heuristics (deposit reuse, DeFi interactions, Layer-2 links) suggest:
- Average addresses per entity (ā): 2.0–7.0.
- Implied entities: 12–25 million (central: 15–20 million).
- Non-human entities (exchanges, bots, protocols): 15–25%.
- Human owners: ~10–20 million.

| Scenario | ā | Entities (millions) | Humans (millions, 20% non-human) |
|----------|---|---------------------|----------------------------------|
| Low Reuse | 2.0 | 32.4 | 25.9 |
| Moderate | 3.0 | 21.6 | 17.3 |
| Central | 4.0 | 16.2 | 13.0 |
| High Reuse (Post-L2) | 5.5 | 11.8 | 9.4 |
| Extreme | 7.0 | 9.3 | 7.4 |

This distribution is more egalitarian than ETH's (top 0.3% hold 95%, per Celig et al., 2025), decoupling FAIR from wealth concentration.

### 2.3 Related Work

- Clustering: Victor (2020), Grandjean (2022), Meier et al. (2025).
- Classification: Bonifazi et al. (2022, 2025).
- Wealth: Sai et al. (2021), Celig et al. (2025).
- User Estimates: a16z (2025) ~10–15M unique Ethereum users.

---

## 3. Protocol Design

### 3.1 Core Components

1. **Eligibility & Claiming**: Merkle-proven whitelist; one claim per address.
2. **Referral System**: Multi-root forest with mutual signatures.
3. **AMM**: Constant-product FAIR/ETH pool with fee splits.
4. **Governance**: Parameter tuning only.

### 3.2 Claiming Mechanics

- **Requirements**: Merkle proof, unclaimed address, AMM ETH >0.
- **Bootstrap**: First 100 claims need no invite; become roots.
- **Minting**: 100 FAIR/claim.
  - 90 to claimant.
  - Up to 4 to referrers (1/level, max 4 levels).
  - ≥6 to AMM (base + unused referrals).
- **Supply**: Total = 100 × claims; no cap beyond whitelist.

### 3.3 Referral System

- **Structure**: Forest with 100 roots; each node invites up to 4 children.
- **Invites**: Mutual ECDSA signatures on EIP-712 message (inviter, invitee, nonce, contract, chain ID).
- **Rewards**: 1 FAIR/level up to 4; unused to AMM.
- **Capacity**: Fixed at 4; non-transferable, no regeneration.

Example: Full chain → 90 claimant, 4 referrers, 6 AMM.

### 3.4 AMM Design

- **Invariant**: X (ETH) × Y (FAIR) = k.
- **Bootstrapping**: Starts empty; claims gated on X >0.
- **Donations**: Irreversible; from claims (6–10 FAIR) and voluntary.
- **Swaps**: 0.3% fee.
  - 0.1% pool (grows k).
  - 0.1% burn FAIR.
  - 0.1% ETH to deployer (D).
- **Properties**: Non-withdrawable; arbitrage from claims builds depth.

### 3.5 Governance

- **Adjustable**: Referral depth/invite cap, fee splits (within bounds), bootstrap size.
- **Immutable**: Core logic, pool drainage, arbitrary mints.
- **Mechanism**: DAO with timelocks (e.g., 30 days) and multi-sig.

---

## 4. Enhancements and Improvements

Based on analysis, the following are incorporated:

### 4.1 Sybil Resistance Upgrades

- **Optional ZK Proofs**: Claimants proving uniqueness (e.g., via Worldcoin or Gitcoin) receive +10 FAIR bonus.
- **Dynamic Penalties**: On-chain clustering (e.g., Meier 2025 heuristics) reduces invite slots for suspected multi-address entities.

### 4.2 Adoption Boosters

- **Donor Incentives**: NFTs/badges for ETH donors, yielding governance points.
- **Phased Claims**: Priority for high-gas addresses (>0.1 ETH) in week 1.
- **UI Simplifications**: dApp for signature generation; opt-in public invites.

### 4.3 Economic Refinements

- **Mild Decay**: B_claim = 90 - (0.01 × claims / 1,000,000) to soft-cap supply.
- **Fee Evolution**: f_dev halves every 1M claims; add 0.05% treasury for marketing.
- **Liquidity Safeguards**: Governance-triggered ETH injections if Y/X > threshold.

### 4.4 Ecosystem Integration

- **Layer-2 Bridges**: Extend to Optimism/Arbitrum for lower fees.
- **Utility**: FAIR as voting token for Ethereum grants DAO.

---

## 5. Economic Analysis

### 5.1 Supply Dynamics

- Minted: 100 × claims (potential max ~6.5B if all claim).
- Burns: ~0.1% of trade volume; under 10% claim-to-trade ratio, offsets 5–10% emissions.
- Scenarios: At 1M claims, supply=100M; pool ~10M FAIR (10%).

### 5.2 Incentives

- Claimants: Immediate 90 FAIR + invite potential.
- Referrers: Up to 4 FAIR/claimee (capped).
- Traders: Arb opportunities from claims.
- Deployer: Volume-based ETH (e.g., 0.1% of $1M daily volume = $1K/day).
- Donors: Indirect via deeper markets.

### 5.3 Risks

- Inflation: Mitigated by decay/burns.
- Stagnation: Phased rollout to seed activity.
- Concentration: Clustering limits multi-address advantages.

---

## 6. Security and Threat Model

### 6.1 Assumptions

- Honest EVM; rational adversaries.
- Secure signatures (ECDSA/EIP-712).
- Audited contracts (focus: replays, overflows, proofs).

### 6.2 Threats

- Sybil: Address-level only; mitigated by clustering/ZK.
- Front-Running: Timelocks on governance.
- Oracle-Free: No externals; pure on-chain.
- Replay: Nonces in invites.

### 6.3 Audits and Simulations

Recommend formal verification, game-theoretic modeling of forest growth, and testnet deployment.

---

## 7. Implementation Roadmap

- **Phase 1**: Audit core contracts; testnet launch.
- **Phase 2**: Mainnet deployment; monitor claims/pool.
- **Phase 3**: Governance activation; L2 bridges.
- **Future**: Integrate off-chain signals (e.g., KYC for bonuses).

---

## 8. Conclusion

FairDAO represents a paradigm shift toward transparent, broad-based token launches. By combining a robust whitelist, bounded referrals, permanent liquidity, and balanced incentives, it achieves wider reach and resilience than traditional models. With 2025's ecosystem maturity, FairDAO could distribute to millions while fostering sustainable growth. Future iterations will refine based on on-chain data.

---

## References

- Bonifazi et al. (2022, 2025). User spectra and clustering.
- Celig et al. (2025). ETH distribution.
- Grandjean (2022). Ethereum clustering.
- Meier et al. (2025). Account-based heuristics.
- Sai et al. (2021). Wealth inequality.
- Tang et al. (2022). Tornado Cash analysis.
- Victor (2020). Address heuristics.
- a16z (2025). State of Crypto.

---
