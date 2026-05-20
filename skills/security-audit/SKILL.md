---
name: security-audit
description: Analyze source code for common security vulnerabilities across Web/API, Embedded/Safety-Critical, and Web3/Smart Contract platforms.
---

# Security Audit Skill

This skill provides domain-specific security checklists and threat models to guide code audits across different platforms.

---

## 1. Web & API Applications

### Injection Attacks
- [ ] **SQL Injection**: All queries use parameterized / prepared statements; ORM is used correctly (no `.raw()` with unvalidated user input).
- [ ] **Command Injection**: Shell execution is avoided; arguments are passed as arrays/lists rather than raw shell strings; input is validated against a strict allow-list.
- [ ] **XSS (Cross-Site Scripting)**: Contextual output encoding is applied; template engines escape by default; unsafe methods (e.g., `innerHTML`, `dangerouslySetInnerHTML`) are avoided.
- [ ] **Path Traversal**: File paths are validated against allowed directories using canonicalization (`realpath`) to prevent directory traversal (`../`).

### Authentication & Authorization
- [ ] **Password Handling**: Passwords hashed with `argon2`, `bcrypt`, or `scrypt`. Plaintext passwords never stored or logged.
- [ ] **Sessions**: CSRF tokens enforced; session cookies configure `HttpOnly`, `Secure`, and `SameSite` flags; sessions invalidated on logout.
- [ ] **Access Control**: Authorization checked server-side on *every* request (IDOR prevention). Resource ownership is explicitly verified.

### Network & API Concerns
- [ ] **Rate Limiting**: Enforced on authentication endpoints, password resets, and resource-intensive actions.
- [ ] **SSRF**: URL schemes restricted to `http/https`, internal IP ranges blocked, DNS rebinding prevented, and redirects limited.
- [ ] **CORS**: Wildcard (`*`) origin prohibited on credentialed endpoints.

---

## 2. Embedded & Safety-Critical Systems

### Memory Safety (C/C++)
- [ ] **Buffer Overflows**: Array bounds checked; unsafe string functions (`strcpy`, `sprintf`, `gets`) replaced with safe alternatives (`strncpy`, `snprintf`, `fgets`); stack protection enabled.
- [ ] **Use-After-Free**: Pointers zeroed/cleared immediately after `free()`; no dangling references to stack variables.
- [ ] **Heap Discipline**: Dynamic allocation avoided post-initialization. Use memory pools with fixed allocations instead.

### Real-Time & Physical Controls
- [ ] **RTOS Constraints**: No blocking operations in interrupt handlers; watchdog timers serviced; priority inversion prevented via inheritance mutexes.
- [ ] **Secure Boot**: Root of trust verified in hardware; anti-rollback downgrade protection; debug interfaces (JTAG/SWD) locked.
- [ ] **Physical Security**: Tamper-detection mechanisms; cryptographic keys zeroized on tamper event.

---

## 3. Web3 & Smart Contracts

### Vulnerability Classes
- [ ] **Reentrancy**: Implement Checks-Effects-Interactions pattern; state updates occur *before* external transfers; use `ReentrancyGuard` / `nonReentrant` modifiers.
- [ ] **Integer Overflow**: Solidity 0.8+ checked math (or `SafeMath` library); bounds checks on user inputs.
- [ ] **Oracle Manipulation**: Use decentralized price feeds (e.g. Chainlink TWAP); never rely on single DEX spot prices.
- [ ] **Access Control**: Modifiers check authorization; ensure initialization functions can only be called once.
- [ ] **MEV / Front-Running**: Implement slippage protection parameters, transaction deadline limits, and commit-reveal schemes where appropriate.

---

## Utility Script Usage
You can run automated checks using the script located in `scripts/run_audit.py`:
- Use it to run standard linters (`bandit`, `slither`, etc.) against the codebase.
