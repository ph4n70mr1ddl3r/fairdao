# FairDAO: A Whitelist‑Native Governance DAO for Ethereum Users

**Version 0.3 (concept draft)**  
**Date: November 22, 2025**  
**Author: ph4n70mr1ddl3r**  

---

## Table of Contents

- [Abstract](#abstract)
- [1. Vision: FairDAO as the Primary Object](#1-vision-fairdao-as-the-primary-object)
  - [1.1 DAO‑First, Not Token‑First](#11-dao-first-not-token-first)
  - [1.2 The Whitelist as a Membership Universe](#12-the-whitelist-as-a-membership-universe)
  - [1.3 FAIR's Three Roles](#13-fairs-three-roles)
- [2. Architecture Overview](#2-architecture-overview)
  - [2.1 Governance vs Hard Invariants](#21-governance-vs-hard-invariants)
- [3. Whitelist‑Native Onboarding into FairDAO](#3-whitelist-native-onboarding-into-fairdao)
  - [3.1 Eligibility and Merkle Root](#31-eligibility-and-merkle-root)
  - [3.2 One‑Time Claim and DAO Entry](#32-one-time-claim-and-dao-entry)
  - [3.3 Gating Claims on ETH Liquidity](#33-gating-claims-on-eth-liquidity)
  - [3.4 Bootstrap Roots (First 100 Claimants)](#34-bootstrap-roots-first-100-claimants)
- [4. Referral System as Discovery Mechanism](#4-referral-system-as-discovery-mechanism)
  - [4.1 Fixed Invite Slots per Member](#41-fixed-invite-slots-per-member)
  - [4.2 Mutual‑Signature Invite Pairs](#42-mutual-signature-invite-pairs)
  - [4.3 Four‑Level Referral Rewards](#43-four-level-referral-rewards)
  - [4.4 Referral System as DAO Outreach](#44-referral-system-as-dao-outreach)
- [5. FAIR/ETH AMM as the DAO's Liquidity Commons](#5-faireth-amm-as-the-daos-liquidity-commons)
  - [5.1 Constant‑Product AMM with Non‑Withdrawable Core](#51-constant-product-amm-with-non-withdrawable-core)
  - [5.2 Bootstrapping and ETH Donations](#52-bootstrapping-and-eth-donations)
  - [5.3 Swap Fee and Fee Split](#53-swap-fee-and-fee-split)
  - [5.4 AMM as Entry and Exit for Governance](#54-amm-as-entry-and-exit-for-governance)
- [6. Governance: FAIR as the Governance Token](#6-governance-fair-as-the-governance-token)
  - [6.1 Basic Model](#61-basic-model)
  - [6.2 What Governance Controls](#62-what-governance-controls)
  - [6.3 What Governance Cannot Do](#63-what-governance-cannot-do)
  - [6.4 Fair Representation and Evolution](#64-fair-representation-and-evolution)
- [7. Security and Assumptions (High Level)](#7-security-and-assumptions-high-level)
- [8. Roadmap (Informative)](#8-roadmap-informative)
- [9. Conclusion](#9-conclusion)
- [10. Glossary](#10-glossary)
- [11. Technical Specifications](#11-technical-specifications)

---

## Abstract

FairDAO is a governance DAO designed first and foremost as a **home for Ethereum users**, not as a speculative token experiment. The core object of the system is the **DAO itself**, and the FAIR token is its **governance token**. Everything else in the protocol — the distribution mechanism, the Ethereum‑native whitelist, the automated market maker, and the referral system — exists only to **onboard members fairly**, give them **liquidity**, and **reach as many eligible users as possible**.

The DAO’s membership “universe” is defined by a concrete Ethereum whitelist: 64,846,015 externally owned accounts (EOAs) that each paid at least 0.004 ETH in cumulative gas fees up to block 23,000,000. Prior clustering and ownership analysis suggests that this set corresponds to roughly 10–20 million human owners. These addresses are treated as the **maximal set of potentially eligible FairDAO members**. Any address on this list may join the DAO once, by claiming FAIR via an on‑chain claim contract.

The FAIR token plays three roles at once:

1. **Governance token:** FAIR is the governance token of FairDAO. Holding FAIR gives the right to participate in DAO governance (proposal, voting, delegation) over protocol parameters and future versions, within strict guardrails that protect core invariants.
2. **Membership credential:** Claiming FAIR as an eligible address is the canonical way to “register” into FairDAO. The DAO’s initial voting power is seeded by this ex‑post, gas‑based view of the Ethereum population.
3. **Liquidity asset:** FAIR trades against ETH in a non‑withdrawable constant‑product automated market maker (AMM), so that:
   - Whitelisted users who claim but do not want long‑term exposure can sell their FAIR.  
   - Non‑whitelisted users or institutions who want to participate in FairDAO governance can buy FAIR on the open market.

Every successful claim mints a fixed **100 FAIR**, split as:

- 90 FAIR to the claimant (who joins the DAO as a voting participant),  
- up to 4 FAIR to referrers in a 4‑level bounded invite forest, and  
- at least 6 FAIR (plus any unused referral portion) permanently donated to the FAIR/ETH AMM.

Claims are **gated** on the AMM holding positive ETH: no one can claim FAIR until there is ETH in the pool, ensuring that distribution always coincides with real, tradable liquidity between FAIR and ETH.

The AMM charges a **0.3% swap fee**, split as:

- 0.1% retained in the pool (growing liquidity and deepening the DAO’s “liquidity commons”),  
- 0.1% burned as FAIR (soft deflation, partially offsetting emissions),  
- 0.1% paid in ETH to the original deployer as a transparent, bounded development incentive.

All invitations into the DAO (after an initial bootstrap) are structured as **mutually signed relationships** between inviter and invitee, forming a bounded 4‑ary “invite forest” that helps the DAO reach and activate more of the whitelist while avoiding unbounded MLM‑style dynamics.

The result is a protocol where the **DAO is the center**: FAIR is its governance token; the whitelist defines who can natively join; the distribution and referral logic onboard those users; and the AMM provides a permanent, neutral bridge between those inside and outside the whitelist.

---

## 1. Vision: FairDAO as the Primary Object

### 1.1 DAO‑First, Not Token‑First

Most “fair launch” projects start with a token and then improvise governance on top. FairDAO takes the opposite approach:

- The primary design target is a **governance DAO representing a broad slice of Ethereum users**.  
- The FAIR token is designed from the beginning as **the governance token of this DAO**.  
- Token distribution, AMM design, and referral mechanisms are viewed as **onboarding infrastructure** — not as ends in themselves.

This perspective leads to three guiding principles:

1. **Representation:** The DAO should be grounded in an objectively defined, economically meaningful subset of Ethereum users.  
2. **Fair Access:** People in that universe should have a fair, one‑per‑address opportunity to join.  
3. **Permeability:** Others outside that universe should be able to buy in and participate, but not at the expense of the original distribution’s fairness.

### 1.2 The Whitelist as a Membership Universe

FairDAO’s membership universe is defined by an ex‑post Ethereum whitelist:

- **Chain:** Ethereum mainnet, blocks 0 → 23,000,000 (genesis to circa mid‑2025).  
- **Rule:** externally owned accounts (EOAs) that paid **≥ 0.004 ETH** in cumulative gas across this window.  
- **Size:** **64,846,015 addresses**, forming a highly non‑trivial subset of the Ethereum user base.

Empirical clustering and ownership estimation on this list suggests that it corresponds to approximately:

- **12–25 million distinct entities** (address clusters),  
- **≈10–20 million human owners** after conservatively discounting exchanges, protocols, bots, and other non‑human entities.

This whitelist is not specific to FairDAO. It is an independent dataset that captures **real economic activity** on Ethereum. FairDAO simply chooses to **adopt it as its membership universe**, using a Merkle root of the whitelist in the claim contract.

### 1.3 FAIR’s Three Roles

FAIR is designed as a **single token fulfilling three roles**:

1. **Governance token of FairDAO**  
   - FAIR holders propose, vote, and delegate in the DAO.  
   - Holding FAIR, regardless of how it was acquired (claim vs purchase), constitutes participation in FairDAO governance.

2. **On‑chain membership credential**  
   - For addresses on the whitelist, claiming FAIR is the canonical way to join the DAO with a “native” allocation.  
   - The initial distribution effectively maps Ethereum’s gas‑paying population into FairDAO’s voter set.

3. **Liquidity & access asset**  
   - The FAIR/ETH AMM allows:
     - Claimants who do not want long‑term exposure to **sell** FAIR.  
     - Non‑whitelisted parties (or those who missed the claim window) to **buy** FAIR and acquire governance rights.

The rest of the protocol — claims, whitelist, AMM mechanics, fees, and referrals — is designed around serving these three roles.

---

## 2. Architecture Overview

FairDAO’s on‑chain architecture has four main components:

1. **Governance Layer (FairDAO proper)**  
   - A governance contract (or set of contracts) where FAIR holders vote on parameter changes, future versions, and DAO‑level decisions.

2. **Whitelist‑Based Claim & Referral Contract**  
   - Lets eligible addresses claim FAIR once, subject to the whitelist and invite rules, and feeds part of each claim into the AMM.  
   - Implements the 100 FAIR per claim rule and the 90/4/6 split (claimant / referrers / AMM).

3. **FAIR/ETH AMM (Liquidity Commons)**  
   - A constant‑product pool holding FAIR and ETH.  
   - Non‑withdrawable core liquidity: no LP tokens, no “rug” function.  
   - Carries swap fees that feed liquidity, burn FAIR, and pay a small ETH fee to the deployer.

4. **Off‑Chain Infrastructure**  
   - Hosts the full whitelist and per‑address Merkle proofs.  
   - Provides frontends for claiming, inviting, voting, and trading via the AMM.  
   - May host analytics and governance dashboards for FairDAO.

### 2.1 Governance vs Hard Invariants

A key design choice is to **separate tunable parameters from core invariants**:

- **Hard invariants (not governable):**
  - The FAIR/ETH AMM core liquidity cannot be withdrawn.  
  - Claims always mint exactly 100 FAIR.  
  - Historical claim states and swap history cannot be rewritten.  
  - The whitelist root, once set, is immutable.

- **Governable parameters (within guardrails):**
  - Referral depth and per‑level reward splits.  
  - Invite capacity per member.  
  - Claim window start/end.  
  - AMM fee split ratios, within bounds (e.g., 0.3% total, but varying pool/burn/dev proportions).  
  - Funding and deployment of future versions or ancillary contracts.

This separation keeps the core **fairness and safety properties procedurally guaranteed**, while allowing the DAO to adapt peripheral aspects over time.

---

## 3. Whitelist‑Native Onboarding into FairDAO

### 3.1 Eligibility and Merkle Root

FairDAO uses the whitelist as its **eligibility set**:

- Off‑chain, the full list of 64,846,015 addresses is stored and associated with Merkle proofs.  
- On‑chain, the claim contract stores only the **Merkle root**.  
- An address proves eligibility by submitting a Merkle proof linking its address to the root.

The whitelist is **immutable** from the contract’s perspective: no new addresses can be added after deployment. This ensures that **no one can game the system ex ante**; all qualifying activity happened long before FairDAO existed.

### 3.2 One‑Time Claim and DAO Entry

Each address on the whitelist can claim **exactly once**. A successful claim does three things at once:

1. **Mints 90 FAIR** to the claimant, onboarding them as a FairDAO governance participant.  
2. **Mints up to 4 FAIR** to referrers (if any), rewarding the social network that helped discover this address.  
3. **Mints the remainder (6–10 FAIR)** directly into the FAIR/ETH AMM, deepening the DAO’s liquidity commons.

Formally, each successful claim mints exactly **100 FAIR**:

- 90 FAIR → claimant  
- 4 FAIR → referral budget (1 FAIR per level, up to 4 levels)  
- 6 FAIR → base AMM donation  
- unused referral portion (if some levels don’t exist) → also donated to the AMM

Total minted per claim: 100 FAIR, with no decay schedule or time‑dependent bonuses.

### 3.3 Gating Claims on ETH Liquidity

Claims are **only permitted** if the FAIR/ETH AMM currently holds **non‑zero ETH**. That is:

- Let `X` be the AMM’s ETH balance.  
- A claim is allowed only if `X > 0`.  
- If `X == 0`, claim transactions revert.

This gating ensures that:

- The pool never becomes a “FAIR‑only sink”.  
- The moment new FAIR enters the AMM via claims, there is already ETH present to define a **real, tradable price**.  
- Early claimants are not stuck holding an illiquid token; liquidity and governance rights come online together.

Practically, this means **someone must donate ETH to the AMM before any claims can be processed** — often the deployer or early supporters. This initial donation is not rewarded with LP tokens; it is a contribution to the DAO’s liquidity commons.

### 3.4 Bootstrap Roots (First 100 Claimants)

To avoid privileging any single “founder” address, FairDAO uses a **multi‑root bootstrap**:

- The first `N_boot = 100` successful claimants do **not** need an invitation.  
- Each bootstrap claimant receives 90 FAIR and becomes a **root** of an invite tree.  
- For these claims, there are no referrers, so the full 10 FAIR community share (4 referral budget + 6 base) is donated to the AMM.  
- Immediately after claiming, each root receives 4 invite slots.

This creates **up to 100 root nodes** in the invite forest — a broad set of initial FairDAO members seeded directly from the whitelist, without any special founder allocation.

**Invite Forest Structure:**

```
                  [Bootstrap Root 1]
                  /   |   |   \
               [1a]  [1b] [1c] [1d]  (4 slots)
                /  \
             [1a1] [1a2] ...
                  |
                [1a2a] ...
                  |
                [1a2a1] ...

                  [Bootstrap Root 2]
                  /   |   |   \
               [2a]  [2b] [2c] [2d]

                  ...

Max depth: 4 levels of rewards
Max children: 4 per node
```

---

## 4. Referral System as Discovery Mechanism

The whitelist is large, and many eligible addresses may never notice they are part of FairDAO unless someone tells them. The referral system is designed as a **bounded discovery mechanism**: it incentivizes **informing** and **activating** whitelisted addresses without devolving into a pyramid scheme.

### 4.1 Fixed Invite Slots per Member

Every address that successfully claims FAIR receives **4 invitation slots**:

- These slots are non‑transferable and non‑replenishing.  
- Inviting an address consumes 1 slot, and that slot is permanently used.  
- There is no way to buy or mint additional invite capacity.

This ensures that **each member’s ability to grow the tree is capped**, keeping the invite forest structurally constrained.

### 4.2 Mutual‑Signature Invite Pairs

Invitations are **not public codes** that anyone can steal. Instead, each invitation is a **mutually signed pairwise relationship**:

1. The inviter and invitee agree off‑chain that they want to form an invite relationship.  
2. They construct a structured message `m_pair` containing at least:
   - inviter address  
   - invitee address  
   - claim contract address  
   - chain ID  
   - invite slot index / nonce
3. The inviter signs `m_pair` → `sig_inviter`.  
4. The invitee signs the same `m_pair` → `sig_invitee`.

On‑chain, when the invitee claims, the contract verifies:

- Both signatures are valid and correspond to `inviter` and `invitee`.  
- The inviter has at least one remaining slot.  
- The `(inviter, invitee, nonce)` combination has not been used before.  
- The invitee is indeed the address presenting the Merkle proof.

Only then is the invite consumed, and the invitee is attached to the inviter as a child in the forest.

**Consequences:**

- If an inviter posts some representation of their invite online, **no random third party can hijack it**, because they cannot forge the invitee’s signature.  
- The invite graph reflects **real, mutual consent** between pairs of addresses.

### 4.3 Four‑Level Referral Rewards

The referral rewards are **bounded**:

- A claim can pay at most **4 FAIR** to referrers, one per level, up to **4 levels** upwards in the forest.  
- If the tree above a claimant is shallower than 4 levels, the unused portion of the 4 FAIR budget is redirected to the AMM.

Examples:

- If four levels exist above the claimer:
  - 90 FAIR → claimer  
  - 4 × 1 FAIR → 4 ancestors  
  - 6 FAIR → AMM
- If only two levels exist:
  - 90 FAIR → claimer  
  - 2 FAIR → 2 ancestors  
  - 8 FAIR → AMM

The invite forest can grow to arbitrary depth, but **only the first four levels above a claim receive rewards**. This prevents unlimited reward chains and keeps referral incentives simple and transparent.

### 4.4 Referral System as DAO Outreach

Conceptually, the referral system is not primarily about extracting value; it is about **reaching the whitelist**:

- Each member can bring in up to 4 additional whitelisted addresses, and is gently incentivized to do so.  
- The structure creates a forest of social links that overlays the static whitelist, capturing “who invited whom” into FairDAO.  
- The DAO can analyze this forest over time to understand its own **growth pattern**, **geography**, and **social topology**.

Referral rewards simply align economic incentives with the **DAO’s core goal**: getting more of the rightful whitelist members to claim FAIR and join governance.

---

## 5. FAIR/ETH AMM as the DAO’s Liquidity Commons

The FAIR/ETH AMM is the **economic interface** between FairDAO and the rest of the world:

- It lets **whitelisted members** who claim their FAIR adjust their exposure or exit.  
- It lets **non‑whitelisted users and institutions** buy FAIR and thereby **acquire governance rights** in FairDAO.  
- It anchors the FAIR price in ETH and attracts arbitrage that keeps it aligned with external markets.

### 5.1 Constant‑Product AMM with Non‑Withdrawable Core

The AMM is a simple constant‑product pool:

- Balances: `X` ETH and `Y` FAIR.
- Invariant: `X · Y = k`, between state‑transition events.
- Price: `P_FAIR(ETH) = X / Y` on the marginal trade.

**Mathematical Formulation:**

```
Initial state:  (X₀, Y₀)
After swap:    (X₁, Y₁)
Invariant:      X₀ · Y₀ = k = X₁ · Y₁

Swap ETH for FAIR:
  amountIn = ΔX
  amountOut = Y₀ - (k / (X₀ + ΔX))

Swap FAIR for ETH:
  amountIn = ΔY
  amountOut = X₀ - (k / (Y₀ + ΔY))
```

Crucially, the core liquidity is **non‑withdrawable**:

- There are no LP tokens.  
- There is no function to withdraw a pro‑rata share of the pool.  
- The only way to move assets in or out is via swaps or direct donations.

This makes the AMM a kind of **“liquidity commons”** owned collectively by the DAO’s users, not by a set of LPs.

### 5.2 Bootstrapping and ETH Donations

At deployment, `X = Y = 0`. Claims are disabled until some ETH is donated:

1. A donor (possibly the deployer) sends ETH to the AMM.
2. Once `X > 0`, claims are enabled.
3. As claims occur, FAIR starts to flow into the AMM from the 6–10 FAIR per‑claim donation, and a live FAIR/ETH price emerges.

**AMM State Flow:**

```
DEPLOYMENT:
  ETH: 0     FAIR: 0     k: 0     [CLAIMS DISABLED]

INITIAL DONATION:
  ETH: 100   FAIR: 0     k: 0     [CLAIMS ENABLED]

AFTER 100 CLAIMS (bootstrap):
  ETH: 100   FAIR: 1000  k: 100,000  (10 FAIR to AMM each)

AFTER 10,000 CLAIMS:
  ETH: 100   FAIR: 100,000  k: 10,000,000
  Price: 0.001 ETH/FAIR

AFTER SWAP ACTIVITY:
  ETH: 150   FAIR: 75,000   k: 11,250,000 (k grows from fees)
  Price: 0.002 ETH/FAIR
```

ETH donations are **pure contributions** — the donor receives no LP token, only indirect benefits from a more liquid governance token and a healthier DAO.

### 5.3 Swap Fee and Fee Split

Swaps in the AMM pay a **0.3% fee**, split three ways:

- **0.1% to the pool (`f_pool`)**  
  - Increases `X` or `Y` (depending on direction), making the pool deeper over time.  
  - Causes `k` to grow with volume.

- **0.1% burned as FAIR (`f_burn`)**  
  - Reduces total FAIR supply as trading happens.  
  - Partially offsets the inflation from the 100 FAIR per claim schedule.

- **0.1% to the deployer in ETH (`f_dev`)**  
  - Provides a small, bounded revenue stream to the original deployer.  
  - Intended as an **incentive to maintain and improve** the protocol (infrastructure, frontends, research, audits).  
  - Can be redirected or subject to DAO oversight in future versions.

The parameters of this split are **governable within bounds**. For example, FairDAO could vote to reduce `f_dev` over time, or redirect it to a DAO treasury or grants program, subject to the constraints encoded in the deployed contracts.

### 5.4 AMM as Entry and Exit for Governance

The AMM is directly tied to governance via FAIR:

- **Exit for whitelisted members:**  
  - A user who has claimed FAIR and does not want to participate further can sell their FAIR for ETH.  
  - They effectively “cash out” of FairDAO while contributing to pool depth and possibly burning a small portion of their tokens via fees.

- **Entry for non‑whitelisted users:**  
  - Anyone can buy FAIR from the AMM (or other markets) and **join governance**.  
  - Governance rights are not restricted to claimants; they are held by whoever owns FAIR at any given time.

This dual role makes the AMM an **on‑chain market for DAO membership and influence**, but one whose core liquidity cannot be abruptly withdrawn.

---

## 6. Governance: FAIR as the Governance Token

### 6.1 Basic Model

FAIR is the **governance token of FairDAO**:

- One FAIR corresponds to one unit of voting power (baseline model).  
- Holders can:
  - Submit and vote on proposals.  
  - Delegate their voting power.  
  - Decide on upgrades and parameter changes within hard limits.

The governance layer can be implemented using familiar patterns (e.g., Governor‑style contracts) with appropriate modifications for this specific protocol.

### 6.2 What Governance Controls

Within predefined guardrails, FairDAO can control:

- **Distribution parameters** (for future phases):  
  - When to close the claim window.  
  - Whether to introduce secondary or late‑join phases.

- **Referral and invite parameters:**  
  - Number of invite slots per member.  
  - Referral depth and per‑level reward sizes.  
  - Whether to relax or tighten invite rules over time.

- **AMM and fee parameters:**  
  - Exact split of the 0.3% fee between pool, burn, and dev/treasury, as long as the total fee does not exceed the encoded cap.  
  - Introduction of secondary pools or routing mechanisms.

- **New versions and auxiliary contracts:**  
  - Deployment of new contracts that extend or supersede parts of the system.  
  - Incentive programs, grants, and bounties funded by separately created treasuries.

### 6.3 What Governance Cannot Do

To preserve fair launch guarantees and protect minority holders, certain things are **intentionally outside governance’s reach**:

- Governance cannot introduce a function that drains the FAIR/ETH AMM core liquidity.  
- Governance cannot arbitrarily seize FAIR from holders or change historical claim records.  
- Governance cannot mint FAIR outside the fixed “100 FAIR per claim” schedule in the base contracts, except via **explicitly separate extensions** that users opt into.

If new versions or extensions are launched, they will be **opt‑in**: FAIR holders and users must explicitly interact with them. Existing contracts keep working exactly as deployed.

### 6.4 Fair Representation and Evolution

Because the initial distribution is one‑per‑whitelisted address, FairDAO starts with a broadly dispersed set of governance rights. Over time:

- Some claimants will sell, concentrating FAIR.
- Some buyers will accumulate FAIR and become large voters.
- The DAO may introduce additional mechanisms (e.g., delegation incentives, quadratic weighting on certain decisions, or non‑binding signaling) to maintain a balance between expertise and decentralization.

Those choices are themselves governance decisions — but they are **made by FAIR holders**, not by a pre‑mine or off‑chain committee.

### 6.5 Deployment Checklist

Before mainnet deployment, verify:

- [ ] Merkle root is correctly computed from full whitelist
- [ ] FAIR token has correct initial supply (0, minted via claims)
- [ ] AMM has non-withdrawable core liquidity (no LP tokens)
- [ ] Fee splits are correctly implemented (0.1%/0.1%/0.1%)
- [ ] Claim window start time is set appropriately
- [ ] Governance timelock is configured (recommended: 48 hours)
- [ ] Emergency pause functionality is available and tested
- [ ] All contracts have been audited by at least two independent firms
- [ ] Testnet deployment completed with successful dry run
- [ ] Off-chain infrastructure (Merkle proof serving) is operational

---

## 7. Security and Assumptions (High Level)

FairDAO’s design rests on several assumptions:

1. **Ethereum Execution Correctness**  
   - The EVM executes contracts faithfully.  
   - Consensus and finality behave within expected bounds.

2. **Whitelist Correctness**  
   - The Merkle root in the claim contract accurately corresponds to the intended whitelist.  
   - Off‑chain infrastructure serving Merkle proofs is honest or at least easily verifiable by users.

3. **Address‑Level Sybil Resistance**  
   - The gas‑based whitelist is assumed to be hard to farm in hindsight.  
   - It does not guarantee human uniqueness, but it strongly skews toward **economically meaningful users**.

4. **Stable Signature Schemes**  
   - The ECDSA and EIP‑712 mechanisms used for invite signatures are secure and correctly implemented in wallets.

5. **Economically Rational Participants**  
   - Users act to improve their own economic position.  
   - The bounded referral system and fee design are tuned under this assumption.

A deeper formal analysis — including invite‑forest growth, liquidity dynamics, and governance game theory — is left for future work and independent research.

### 7.1 Key Security Considerations

#### Merkle Proof Validation
- Ensure proofs cannot be reused across different addresses
- Verify chain ID to prevent replay attacks
- Include claim contract address in signed messages

#### Invite System Security
- Validate that signatures are from expected parties
- Prevent nonce reuse in invite pairs
- Ensure invite slots cannot be transferred or sold

#### AMM Safety
- Prevent integer overflow/underflow in calculations
- Ensure minimum output amounts are respected
- Protect against flash loan attacks (though non-withdrawable core mitigates this)

#### Reentrancy Protection
- All state-changing functions should be nonReentrant
- Use Checks-Effects-Interactions pattern
- Validate state before external calls

### 7.2 Edge Cases and Fail Conditions

| Scenario | Expected Behavior |
|----------|-------------------|
| Claim when AMM has 0 ETH | Transaction reverts with `NoLiquidity()` error |
| Duplicate claim attempt | Transaction reverts with `AlreadyClaimed()` error |
| Invalid Merkle proof | Transaction reverts with `InvalidProof()` error |
| Expired invite deadline | Transaction reverts with `InviteExpired()` error |
| Reused invite pair | Transaction reverts with `InviteAlreadyUsed()` error |
| Swap results in zero output | Transaction reverts with `InsufficientOutput()` error |
| Slippage exceeded | Transaction reverts with `SlippageExceeded()` error |

---

## 8. Roadmap (Informative)

1. **Research & Simulation**  
   - Further analysis of the whitelist and likely uptake.  
   - Simulations of invite‑forest growth under different behaviors.  
   - Liquidity and fee modeling under plausible trading volumes.

2. **Spec Finalization & Audits**  
   - Finalize contract specifications for claim, AMM, and governance.  
   - Conduct independent audits and formal verification where feasible.

3. **Testnet & Dry Runs**  
   - Deploy on a testnet with a subset of the whitelist.  
   - Run test campaigns for invitations, claiming, and AMM trading.

4. **Mainnet Deployment**  
   - Deploy the final contracts.  
   - Seed initial ETH liquidity to enable claims.  
   - Open the claim window and bootstrap roots.

5. **DAO Activation**  
   - Enable on‑chain governance by FAIR holders.  
   - Migrate any previously off‑chain decision‑making into formal proposals and votes.

6. **Iteration & Extensions**  
   - Consider future extensions (treasury management, grants, quadratic experiments, reputation overlays) on top of the base FairDAO.

---

## 9. Conclusion

FairDAO is a **DAO‑first** protocol. Instead of treating governance as an afterthought attached to a token, it treats the **DAO itself as the central object** and designs every other component in service of that object:

- The whitelist defines a large, economically meaningful **universe of potential members**.  
- The claim system, with its fixed 100 FAIR per claim and bounded invite forest, is a way to **onboard those members fairly**.  
- The FAIR/ETH AMM is a **liquidity commons** that lets insiders exit, outsiders join, and the token’s price discover itself without risking a rug.  
- The fee mechanism funds liquidity, burns, and a modest development incentive stream, making ongoing stewardship economically sustainable.  
- Above all, **FAIR is the governance token**: whoever holds FAIR participates in steering the protocol, within constraints designed to protect the core fairness guarantees.

In this way, FairDAO aims to become a **governance home for millions of Ethereum users**, grounded in real on‑chain activity, fairness of access, and a transparent, immutable economic base.

---

## 10. Glossary

| Term | Definition |
|------|------------|
| **AMM** | Automated Market Maker - a type of decentralized exchange protocol that relies on a mathematical formula to price assets |
| **DAO** | Decentralized Autonomous Organization - an organization represented by rules encoded as a computer program |
| **EOA** | Externally Owned Account - an Ethereum account controlled by a private key, not a smart contract |
| **FAIR** | The native governance token of FairDAO |
| **k** | The constant product invariant in an AMM (X · Y = k) |
| **Merkle Proof** | A cryptographic proof that a value is part of a Merkle tree |
| **Merkle Root** | The root hash of a Merkle tree containing all whitelisted addresses |
| **MLM** | Multi-Level Marketing - a marketing strategy where the sales force is compensated not only for sales they generate but also for the sales of the other salespeople they recruit |
| **N_boot** | Number of bootstrap claimants (100) |
| **Whitelist** | The set of 64,846,015 Ethereum addresses eligible to claim FAIR |

---

## 11. Technical Specifications

### 11.1 Data Structures

#### Merkle Tree for Whitelist
```
struct WhitelistInfo {
    bytes32 merkleRoot;          // Root of the whitelist Merkle tree
    uint256 totalAddresses;      // 64,846,015
    uint256 minGasPaid;          // 0.004 ETH
    uint256 endBlock;            // 23,000,000
}
```

#### Invite Tree Structure
```
struct InviteNode {
    address inviter;
    address invitee;
    uint8 level;                 // 0-3 (4 levels)
    uint256 slotIndex;           // 0-3 (4 slots per inviter)
    bool claimed;
}

mapping(address => InviteNode[]) public inviteTree;
mapping(address => uint256) public inviteSlotsUsed;
```

#### AMM State
```
struct AMMState {
    uint256 ethBalance;          // X
    uint256 fairBalance;         // Y
    uint256 k;                   // X * Y constant
    uint256 feeBasisPoints;      // 30 = 0.3%
    uint256 poolFeeShare;        // 10 = 0.1%
    uint256 burnFeeShare;        // 10 = 0.1%
    uint256 devFeeShare;         // 10 = 0.1%
}
```

### 11.2 Key Constants

```
uint256 constant FAIR_PER_CLAIM = 100;
uint256 constant CLAIMANT_SHARE = 90;
uint256 constant REFERRAL_BUDGET = 4;
uint256 constant AMM_BASE_SHARE = 6;
uint256 constant BOOTSTRAP_COUNT = 100;
uint256 constant INVITE_SLOTS_PER_MEMBER = 4;
uint256 constant MAX_REFERRAL_LEVELS = 4;
uint256 constant SWAP_FEE_BASIS_POINTS = 30;  // 0.3%
```

### 11.3 Core Functions

#### Claim FAIR
```
function claim(
    bytes32[] calldata merkleProof,
    address inviter,
    uint256 slotIndex,
    bytes calldata sigInviter,
    bytes calldata sigInvitee
) external nonReentrant whenNotPaused
```

**Requirements:**
- Address must be in whitelist (verified via Merkle proof)
- AMM must have ETH balance > 0
- Address must not have claimed before
- If not in first 100 claimants: valid invite signatures required

#### Swap in AMM
```
function swap(
    bool ethIn,  // true if swapping ETH for FAIR
    uint256 amountIn,
    uint256 amountOutMin
) external nonReversible
```

**Formula:**
```
amountOut = amountIn * (balanceOther - fee) / (balanceThis + amountIn)
```

#### Donate ETH to AMM
```
function donate() external payable
```

Enables claims by providing initial ETH liquidity.

### 11.4 Invite Message Format (EIP-712)

```
struct InviteMessage {
    address inviter;
    address invitee;
    address claimContract;
    uint256 chainId;
    uint256 slotIndex;
    uint256 deadline;
}
```

The message is signed by both inviter and invitee before submission.

### 11.5 Fee Distribution

For a swap of `amountIn`:
```
totalFee = amountIn * 30 / 10000          // 0.3%
poolFee = totalFee / 3                    // 0.1% - added to pool
burnAmount = totalFee / 3                 // 0.1% - FAIR burned
devFee = totalFee / 3                     // 0.1% - sent to deployer
```

### 11.6 State Variables

```
address public immutable FAIR_TOKEN;
address public immutable AMM_ADDRESS;
address public immutable DEPLOYER;
address public immutable GOVERNANCE;

bytes32 public immutable WHITELIST_ROOT;

uint256 public totalClaims;
uint256 public totalFeesToDev;
uint256 public totalFairsBurned;
uint256 public ammK;                       // X * Y constant

mapping(address => bool) public hasClaimed;
mapping(bytes32 => bool) public usedInvitePairs;
```

---

## 12. References

- **EIP-712**: Ethereum typed structured data hashing and signing
- **EIP-2612**: Permit - gasless approvals via signatures
- **Uniswap V2 Whitepaper**: Constant product AMM mechanics
- **Compound Governance**: DAO governance patterns and timelocks
- **Merkle Trees**: Efficient proof systems for large datasets

---

## 13. Changelog

### Version 0.3 (November 22, 2025)
- Initial concept draft
- Complete specification of whitelist-native design
- Detailed AMM and fee mechanics
- Referral system with mutual signatures
- Governance framework with hard invariants

### Future Versions
- Add detailed Solidity interface definitions
- Include simulation results for invite forest growth
- Add economic modeling and tokenomics analysis
- Provide test suite specifications
- Include audit reports and findings```