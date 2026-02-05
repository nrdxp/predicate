# Security: Web3 & Smart Contracts

Domain-specific security considerations for blockchain applications, smart contracts, and decentralized systems.

> **Activate when:** Auditing Solidity, Vyper, Rust (Solana/CosmWasm), or other smart contract code.

---

## Unique Threat Model

Smart contracts differ fundamentally from traditional software:

- **Immutable:** Deployed code cannot be patched (without upgrade patterns)
- **Transparent:** All code and state is publicly visible
- **Adversarial:** Anyone can call any public function with any input
- **High stakes:** Bugs often mean immediate, irreversible financial loss

---

## Critical Vulnerability Classes

### 1. Reentrancy

The DAO Hack pattern. External calls can re-enter the contract before state updates complete.

**Check:**

- [ ] State changes happen BEFORE external calls (Checks-Effects-Interactions)
- [ ] ReentrancyGuard / nonReentrant modifier on state-changing functions
- [ ] No callbacks to untrusted addresses mid-execution

**Pattern to flag:**

```solidity
// VULNERABLE: State update after external call
function withdraw(uint amount) {
    require(balances[msg.sender] >= amount);
    (bool success,) = msg.sender.call{value: amount}("");  // External call
    balances[msg.sender] -= amount;  // State update AFTER call
}
```

---

### 2. Integer Overflow/Underflow

Arithmetic that wraps around, enabling balance manipulation.

**Check:**

- [ ] Solidity 0.8+ (built-in overflow checks) OR SafeMath library
- [ ] Explicit bounds checking on user-supplied values
- [ ] No unchecked blocks around critical arithmetic

---

### 3. Oracle Manipulation

Price oracles can be manipulated, especially on-chain DEX prices.

**Check:**

- [ ] No reliance on single DEX spot price for critical decisions
- [ ] Time-weighted average prices (TWAP) or multi-source oracles
- [ ] Flash loan attack vectors considered
- [ ] Chainlink or equivalent decentralized oracle for price feeds

---

### 4. Access Control

Missing or incorrect authorization checks.

**Check:**

- [ ] Critical functions have `onlyOwner` or role-based modifiers
- [ ] No unprotected `selfdestruct`
- [ ] Initialization functions can only be called once
- [ ] Upgrade/admin functions properly protected

---

### 5. Front-Running (MEV)

Transactions in the mempool can be observed and exploited.

**Check:**

- [ ] Commit-reveal schemes for sensitive operations
- [ ] Slippage protection on swaps
- [ ] Deadline parameters on time-sensitive operations
- [ ] No secret values in transaction calldata

---

### 6. Gas Limit & DoS

Operations that can be made to exceed block gas limits.

**Check:**

- [ ] No unbounded loops over user-controlled arrays
- [ ] Batch operations have size limits
- [ ] External calls in loops have failure handling
- [ ] Pull over push pattern for payments

---

### 7. Signature Vulnerabilities

Cryptographic signature handling errors.

**Check:**

- [ ] Replay protection (nonces, chain ID in signatures)
- [ ] No signature malleability issues (use EIP-712)
- [ ] `ecrecover` return value checked (non-zero)
- [ ] Domain separation in signed messages

---

## Upgrade Pattern Audit

If using upgradeable contracts (proxy patterns):

- [ ] Implementation cannot be initialized after deployment
- [ ] Storage layout preserved across upgrades
- [ ] Upgrade authority properly secured
- [ ] Time-lock on upgrades (if applicable)
- [ ] No storage collisions between proxy and implementation

---

## Economic Invariants

Define and verify financial invariants:

```
// Examples
total_supply == sum(all_balances)
user_balance >= 0
collateral_ratio >= minimum_collateral
```

- [ ] Invariants hold after every state-changing function
- [ ] Edge cases (zero values, max values) tested
- [ ] Flash loan interactions don't break invariants

---

## Checklist Summary

| Category   | Items                                       |
| :--------- | :------------------------------------------ |
| Reentrancy | CEI pattern, guards, callback safety        |
| Math       | Overflow protection, bounds checking        |
| Oracles    | Multi-source, TWAP, flash loan resistant    |
| Access     | Role guards, init protection, no open admin |
| MEV        | Commit-reveal, slippage, deadlines          |
| Gas        | Bounded loops, pull payments                |
| Signatures | Replay protection, EIP-712, malleability    |
| Upgrades   | Storage safety, auth, timelocks             |
