---
name: "security-audit"
description: "Comprehensive, risk-centric security assessment with phased lifecycle"
---

# Security Audit Protocol v1.0

A structured, risk-centric framework for software security assessment. Designed for iterative human engagement with explicit checkpoints at each phase.

> **Core Principle:** The goal is not to maximize bug count, but to identify **business risk**, **architectural flaws**, and **exploitable logic errors**.

---

## Prime Directives

Before beginning, internalize these cognitive framings:

1. **Risk > Findings:** A bug is only a finding if it poses risk to business logic or data integrity. Context determines severity.

2. **Adversarial Mindset:** Analyze every input, endpoint, and public function assuming a capable adversary is attempting to subvert the system.

3. **Taint Analysis Model:** For every potential vulnerability, trace:
   - **Source:** Where does data enter? (user input, API body, URL param)
   - **Sink:** Where is it executed? (SQL query, `eval()`, HTML render, shell)
   - **Sanitizer:** Is there validation between Source and Sink? If not, it's a vulnerability.

4. **Assurance Spectrum:**
   - _Standard code:_ Pattern matching, control flow analysis
   - _Crown jewels:_ Invariant checks, formal verification

---

## Phase 0: Scope & Trust Model

**Objective:** Define boundaries and establish the security context before analyzing code.

### 0.1 Ingest System Context

1. Read manifests (`package.json`, `Cargo.toml`, `go.mod`, `requirements.txt`)
2. Identify tech stack and framework versions
3. Check for known CVEs in dependencies

### 0.2 Define Trust Model

```yaml
TRUST_MODEL:
  UNTRUSTED_SOURCES: # Data entry points
    - "API endpoints"
    - "CLI arguments"
    - "User file uploads"
    - "Environment variables (if user-controlled)"
  TRUSTED_COMPONENTS:
    - "Internal services with mTLS"
    - "Signed configuration files"
  CROWN_JEWELS: # What must be protected
    - "Database credentials"
    - "Private keys"
    - "PII / User data"
    - "Payment processing"
  TRUST_BOUNDARIES: # Where data crosses zones
    - "External API → Internal handler"
    - "User input → Database query"
```

### 0.3 Map Attack Surface

- [ ] Enumerate all public API routes/endpoints
- [ ] Identify CLI entry points and argument parsing
- [ ] List external integrations (webhooks, OAuth, third-party APIs)
- [ ] Document file upload/download paths
- [ ] Note WebSocket or real-time communication channels

**Checkpoint:** Present scope and trust model. Await user approval before proceeding.

---

## Phase 1: Automated Baseline

**Objective:** Establish security baseline through breadth-first automated analysis.

### 1.1 Secret Detection

Search for high-entropy strings and credential patterns:

- `AWS_ACCESS_KEY`, `AZURE_`, `GCP_`
- `Bearer `, `Authorization:`
- Private key headers (`-----BEGIN`)
- Database connection strings
- API keys matching known formats

### 1.2 Dangerous Sink Detection

Search for risky function calls:

| Language   | Dangerous Patterns                                               |
| :--------- | :--------------------------------------------------------------- |
| Python     | `eval()`, `exec()`, `subprocess.call(shell=True)`, `os.system()` |
| JavaScript | `eval()`, `Function()`, `innerHTML`, `dangerouslySetInnerHTML`   |
| Go         | `os/exec` without validation, `template.HTML()`                  |
| Rust       | `unsafe`, `.unwrap()` in library paths, raw pointer manipulation |
| C/C++      | `strcpy`, `sprintf`, `gets`, `system()`, raw `malloc`            |
| SQL        | String concatenation in queries, missing parameterization        |

### 1.3 Configuration Audit

- [ ] Debug mode disabled (`DEBUG=False`, no dev endpoints)
- [ ] Binding addresses (no `0.0.0.0` in production)
- [ ] TLS configuration (minimum TLS 1.2, strong ciphers)
- [ ] CORS policy (no wildcard origins for sensitive APIs)
- [ ] Security headers (CSP, X-Frame-Options, HSTS)

### 1.4 Dependency Vulnerability Check

- [ ] Known CVEs in direct dependencies
- [ ] Outdated packages with security patches available
- [ ] Unmaintained dependencies (no updates in 2+ years)

**Checkpoint:** Present baseline findings. Await acknowledgment before deep review.

---

## Phase 2: Manual White-Box Review

**Objective:** Deep analysis of logic, access control, and architectural patterns that tools miss.

> **Coherence Strategy:** Analyze ONE component at a time. Present findings. Await acknowledgment before proceeding.

### 2.1 Authentication & Session Management

- [ ] Passwords hashed with modern algorithm (bcrypt, argon2, scrypt)
- [ ] No plaintext credential storage or logging
- [ ] Session tokens generated with CSPRNG
- [ ] Session invalidation on logout and password change
- [ ] MFA implementation (if applicable)
- [ ] Brute force protection (rate limiting, account lockout)

### 2.2 Authorization & Access Control

- [ ] Consistent authZ checks on all protected resources
- [ ] No IDOR (Insecure Direct Object Reference) vulnerabilities
- [ ] Horizontal privilege escalation prevented (user A can't access user B's data)
- [ ] Vertical privilege escalation prevented (user can't access admin functions)
- [ ] Default deny policy (explicit grants, not explicit denies)

**IDOR Trace Pattern:**

```
API Endpoint → Extract resource_id from request
            → Verify current_user owns/can_access resource_id
            → If not verified: VULNERABILITY
```

### 2.3 Input Validation & Injection

- [ ] All user input validated against allow-list schemas
- [ ] SQL queries use parameterized statements / prepared statements
- [ ] Command execution avoids shell; if unavoidable, input is escaped
- [ ] Path traversal prevented (no `../` exploitation)
- [ ] Deserialization uses safe parsers (no `pickle`, `yaml.load()` on user input)
- [ ] Integer overflow/underflow handled (especially in financial logic)

### 2.4 Business Logic Errors

Apply state machine analysis:

- Can user do X before Y? (sequence violations)
- Can user trigger action twice? (replay attacks)
- Can user manipulate timing? (TOCTOU)
- Are negative values handled? (refund more than paid)

### 2.5 Concurrency & Race Conditions

- [ ] Shared mutable state protected by locks/mutexes
- [ ] Database transactions use appropriate isolation levels
- [ ] Check-then-act patterns are atomic
- [ ] File operations use proper locking

### 2.6 Cryptography

- [ ] Standard algorithms only (AES-256, RSA-2048+, ECDSA, Ed25519)
- [ ] No deprecated algorithms (MD5, SHA1, DES, RC4)
- [ ] IVs/nonces are unique and random
- [ ] Keys stored securely (vault, HSM, encrypted at rest)
- [ ] No key/IV reuse
- [ ] Proper padding schemes (OAEP for RSA, GCM for symmetric)

### 2.7 Error Handling & Information Disclosure

- [ ] Stack traces not exposed to users
- [ ] Error messages don't reveal system internals
- [ ] Timing attacks mitigated for sensitive comparisons
- [ ] Failed auth doesn't distinguish user existence

### Component Audit Template

For each component, produce:

```
## Audit: [Component Name]

### Attack Surface
- Entry points: [list]
- Data handled: [list]

### Findings
| Category | Rating | Notes |
|:---------|:-------|:------|
| AuthN/AuthZ | PASS/WARN/FAIL | — |
| Input Validation | PASS/WARN/FAIL | — |
| Crypto | N/A/PASS/WARN/FAIL | — |
| Error Handling | PASS/WARN/FAIL | — |

### Vulnerabilities
1. **[SEVERITY]** Brief description — Location

### Questions for User
1. [Clarifying question if needed]
```

**Checkpoint:** Present findings for this component. Await acknowledgment before next component.

---

## Phase 3: Formal Verification (Conditional)

**Trigger:** Apply ONLY to crown jewels—smart contracts, cryptographic primitives, safety-critical logic.

### 3.1 Invariant Definition

Define mathematical properties that must always hold:

- `total_supply == sum(all_balances)`
- `user_balance >= 0`
- `session.expires_at > now() implies session.valid`

### 3.2 Property Verification

- [ ] State machine transitions are exhaustively defined
- [ ] No invalid state is reachable from any valid state
- [ ] Critical invariants hold across all code paths

### 3.3 Traceability

- [ ] Security requirements mapped to code locations
- [ ] Each requirement has corresponding test/proof

**Checkpoint:** Present formal verification scope and findings.

---

## Phase 4: Report Generation

**Objective:** Produce actionable, prioritized findings.

### Severity Classification

| Level        | Definition                                               | Example                                                  |
| :----------- | :------------------------------------------------------- | :------------------------------------------------------- |
| **Critical** | Immediate exploitation possible; complete compromise     | RCE, auth bypass, SQLi with admin access                 |
| **High**     | Significant impact; exploitation requires minimal effort | Stored XSS, privilege escalation, IDOR on sensitive data |
| **Medium**   | Moderate impact or requires specific conditions          | CSRF, information disclosure, weak crypto                |
| **Low**      | Minor impact; defense in depth issue                     | Missing headers, verbose errors, weak rate limiting      |

### Report Structure

```markdown
# Security Audit Report: [Project Name]

## Executive Summary

- **Overall Risk:** [Critical / High / Medium / Low]
- **Summary:** [3-4 sentences, non-technical]
- **Priority Action:** [Single most important fix]

## Threat Model

- **Attack Surface:** [Entry points]
- **Crown Jewels:** [What's at risk]
- **Trust Boundaries:** [Where validation is critical]

## Findings

### [ID-001] [Vulnerability Name]

- **Severity:** Critical/High/Medium/Low
- **Location:** `file:line`
- **Description:** [Technical explanation]
- **Impact:** [Business consequence]
- **Proof of Concept:**
  > [Steps or payload to trigger]
- **Remediation:**
  - _Root Cause:_ [Why this happened]
  - _Fix:_ [Specific code change]

### [ID-002] ... (repeat)

## False Positives

- [Pattern investigated, determined safe, explanation]

## Recommendations (Systemic)

1. [Process or architectural improvement]
```

---

## Master Checklist

Cross-reference all findings against these controls:

### Architecture & Design

- [ ] Trust boundaries defined and enforced
- [ ] Principle of least privilege applied
- [ ] Defense in depth implemented
- [ ] Secrets not hardcoded

### Authentication

- [ ] Strong password policy enforced
- [ ] MFA available for sensitive operations
- [ ] Session management secure
- [ ] Brute force protection in place

### Authorization

- [ ] RBAC correctly implemented
- [ ] No privilege escalation paths
- [ ] Default deny policy

### Input Handling

- [ ] All input validated
- [ ] Output properly encoded
- [ ] File uploads sanitized
- [ ] No injection vulnerabilities

### Cryptography

- [ ] Modern algorithms only
- [ ] Keys properly managed
- [ ] TLS properly configured

### Infrastructure

- [ ] No security misconfigurations
- [ ] Logging and monitoring adequate
- [ ] Patch management in place

---

## Domain-Specific Extensions

During **Phase 0 (Scope)**, identify the tech stack and load the appropriate security fragment. These provide specialized checklists and vulnerability patterns.

### When to Load Each Fragment

**Load `fragments/security-web3.md` if:**

- Auditing Solidity, Vyper, or other smart contract languages
- Target is a blockchain application, DeFi protocol, or NFT system
- Code handles tokens, balances, or on-chain state
- Upgrade patterns (proxy contracts) are in use

**Load `fragments/security-embedded.md` if:**

- Auditing C/C++ firmware or RTOS applications
- Target has real-time constraints or safety requirements
- DO-178C, ISO 26262, or IEC 62443 compliance is required
- Code runs on microcontrollers, automotive ECUs, or medical devices

**Load `fragments/security-web.md` if:**

- Auditing a web application or REST/GraphQL API
- Using Python, Node.js, Go, Ruby, or similar web frameworks
- Target handles user authentication, sessions, or file uploads
- Code is publicly exposed on the internet

> **Note:** Multiple fragments may apply. A Web3 project with a backend API might load both `security-web3.md` and `security-web.md`.

---

## Final Directive

This protocol enforces iterative human engagement. **Never skip checkpoints.** If findings accumulate beyond trackable scope, pause and summarize before continuing.

The goal is not a comprehensive bug list, but **accurate risk assessment** that enables informed remediation decisions.
