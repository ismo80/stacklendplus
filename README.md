# StackLendPlus - Advanced Staking Contract

A comprehensive Clarity smart contract for the Stacks blockchain implementing an advanced staking system with dynamic rewards, referral bonuses, and tiered incentives.

## Features

### Core Staking
- **Flexible Staking**: Deposit STX with optional referrer support
- **Dynamic APR**: Interest rates adjust based on total staked amount
  - < 1M STX: 5% APR
  - 1M - 5M STX: 3% APR
  - > 5M STX: 2% APR

### Reward System
- **Reward Claiming**: Withdraw earned rewards at any time
- **Reward Compounding**: Automatically reinvest rewards to increase stake
- **Lock Period Enhancement**: Extend lock period to earn higher rewards

### Referral Program
- **Referrer Incentives**: 1% bonus to treasury from referred stakes
- **Self-Referral Protection**: Prevents users from referring themselves

### Advanced Features
- **Tiered System**: Users classified as Bronze, Silver, Gold, or Diamond based on stake amount
- **Early Unstake Penalty**: 10% penalty for withdrawing before lock period expires
- **Lock Period**: Default 500 blocks, extensible for enhanced rewards
- **Treasury Management**: Accumulates penalties and referral bonuses

### Admin Controls
- **Owner-Only Functions**: Update base APR rate and early unstake penalty
- **Parameter Flexibility**: Adjust contract parameters without redeployment

## Contract Functions

### Public Functions

#### `stake(amount: uint, referrer: optional principal)`
Deposit STX tokens into the staking contract.
- **Returns**: `(ok "Stake successful")` or `(err ERR_INVALID_AMOUNT)`

#### `claim-reward()`
Withdraw earned rewards.
- **Returns**: Tuple with reward amount or error

#### `extend-lock(extra: uint)`
Extend the lock period for higher rewards.
- **Returns**: `(ok "Lock extended")` or error

#### `unstake()`
Withdraw staked tokens with optional penalty.
- **Returns**: Success message or error

#### `compound()`
Automatically add earned rewards to stake amount.
- **Returns**: `(ok "Reward compounded")` or error

#### `update-params(new-rate: uint, new-penalty: uint)`
Admin function to update contract parameters (owner only).
- **Returns**: `(ok true)` or `(err ERR_NOT_OWNER)`

### Read-Only Functions

- `get-stake(user: principal)` - Get user's stake details
- `get-reward(user: principal)` - Calculate pending rewards
- `get-total-staked()` - Get total staked STX
- `get-apr()` - Get current APR rate
- `get-tier-info(user: principal)` - Get user's tier classification
- `get-treasury()` - Get treasury balance

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| 100 | ERR_NOT_OWNER | Only owner can call this function |
| 101 | ERR_NO_STAKE | User has no active stake |
| 102 | ERR_INVALID_AMOUNT | Amount must be greater than 0 |
| 103 | ERR_ALREADY_REFERRED | User already has a referrer |
| 104 | ERR_INVALID_REFERRAL | Invalid referral address |
| 105 | ERR_NO_REWARD | No rewards available to claim |
| 106 | ERR_LOCK_PERIOD | Lock period not extended |

## Tier Classification

| Tier | Minimum Amount |
|------|---|
| Bronze | 0 STX |
| Silver | 1,000,000 STX |
| Gold | 5,000,000 STX |
| Diamond | 10,000,000 STX |

## Contract Storage

- **owner**: Principal address of contract owner
- **base-rate**: Base APR percentage (default: 2%)
- **total-staked**: Total STX locked in contract
- **lock-period**: Default lock period in blocks (default: 500)
- **referral-bonus**: Referral bonus percentage (default: 1%)
- **early-penalty**: Early unstake penalty (default: 10%)
- **treasury**: Accumulated penalties and bonuses
- **stakes**: Map of user addresses to stake details

## Security Features

- Owner validation for admin functions
- Amount validation to prevent zero deposits
- Early withdrawal penalties to discourage unstaking
- Self-referral protection
- STX transfer verification with `try!` blocks
- All Clarity compiler validations passing

## Usage Example

```clarity
;; Stake 1,000,000 STX with referrer
(contract-call? .stacklendplus stake u1000000 (some 'SPBK1Z5B8RKDJAQJYQNQMHSH5P49JCZD36QFH7D2))

;; Claim rewards
(contract-call? .stacklendplus claim-reward)

;; Extend lock period by 100 blocks
(contract-call? .stacklendplus extend-lock u100)

;; Compound rewards
(contract-call? .stacklendplus compound)

;; Check pending rewards
(contract-call? .stacklendplus get-reward 'SPBK1Z5B8RKDJAQJYQNQMHSH5P49JCZD36QFH7D2)

;; Get user tier
(contract-call? .stacklendplus get-tier-info 'SPBK1Z5B8RKDJAQJYQNQMHSH5P49JCZD36QFH7D2)
