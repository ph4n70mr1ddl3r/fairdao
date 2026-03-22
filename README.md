# FairDAO

A whitelist-native governance DAO for Ethereum users.

## Overview

FairDAO is a governance DAO designed as a home for Ethereum users. The FAIR token serves as the governance token, enabling holders to participate in DAO governance.

### Key Features

- **Whitelist-Native Onboarding**: Eligible Ethereum addresses (EOAs that paid >= 0.004 ETH in gas up to block 23,000,000) can claim FAIR tokens
- **Referral System**: 4-level bounded referral rewards with mutual signature verification
- **FAIR/ETH AMM**: Constant-product automated market maker with non-withdrawable core liquidity
- **Governance**: Token-weighted voting with timelock control

## Contracts

| Contract | Description |
|----------|-------------|
| `FAIR.sol` | ERC20 governance token with voting capabilities |
| `FairAMM.sol` | Constant-product AMM for FAIR/ETH trading (0.3% fee) |
| `FairClaim.sol` | Whitelist-based claiming with referral rewards |
| `FairGovernor.sol` | Governance contract with timelock execution |

## Build

```shell
forge build
```

## Test

```shell
forge test
```

## Format

```shell
forge fmt
```

## Gas Snapshots

```shell
forge snapshot
```

## Deploy

```shell
# Set environment variables
export PRIVATE_KEY=your_private_key
export RPC_URL=your_rpc_url

# Deploy (ensure WHITELIST_ROOT is set in Deploy.s.sol)
forge script script/Deploy.s.sol:DeployFairDAO --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## Token Distribution

Each claim mints exactly **100 FAIR**:
- 90 FAIR to claimant
- Up to 4 FAIR to referrers (1 per level, max 4 levels)
- 6+ FAIR to AMM liquidity

## AMM Fee Structure

- 0.3% total swap fee, split as:
  - 0.1% to pool (grows liquidity)
  - 0.1% burned (deflationary)
  - 0.1% to deployer (development incentive)

## Documentation

See [FAIRDAO.md](./FAIRDAO.md) for the full specification.

## License

MIT
