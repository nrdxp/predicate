# Security: Embedded & Safety-Critical Systems

Domain-specific security considerations for embedded systems, real-time applications, and safety-critical software (avionics, automotive, medical devices).

> **Activate when:** Auditing C/C++ firmware, RTOS applications, or systems requiring DO-178C/ISO 26262 compliance.

---

## Unique Threat Model

Embedded and safety-critical systems have distinct constraints:

- **Resource constrained:** Limited memory, CPU, no virtual memory
- **Real-time requirements:** Security cannot block timing-critical operations
- **Long lifecycle:** Deployed for years/decades with limited update capability
- **Physical access:** Attackers may have hardware access
- **Safety implications:** Bugs can cause physical harm

---

## Memory Safety

The primary attack surface in C/C++ systems.

### Buffer Overflows

- [ ] All array accesses bounds-checked
- [ ] No `strcpy`, `sprintf`, `gets` — use `strncpy`, `snprintf`, `fgets`
- [ ] Stack canaries enabled (`-fstack-protector`)
- [ ] ASLR enabled where possible

### Use-After-Free

- [ ] Clear pointers after `free()`
- [ ] No dangling references to stack variables
- [ ] Object lifetime clearly documented

### Heap Safety

- [ ] Dynamic allocation avoided post-initialization (common requirement)
- [ ] If `malloc` used: all failures handled, no leaks
- [ ] Memory pools with fixed allocation for determinism

---

## Real-Time Constraints

Security mechanisms must not violate timing.

- [ ] No blocking operations in interrupt handlers
- [ ] Cryptographic operations within timing budget
- [ ] Watchdog timers not starved by security code
- [ ] Priority inversion prevented (priority inheritance mutexes)

---

## Secure Boot & Firmware

### Boot Chain

- [ ] Root of trust established in hardware (secure boot)
- [ ] Each boot stage verifies next stage's signature
- [ ] Rollback protection (anti-downgrade)
- [ ] Secure key storage (TPM, secure enclave, OTP)

### Firmware Updates

- [ ] Updates signed and verified before application
- [ ] Partial/failed updates recoverable
- [ ] Update mechanism itself not exploitable
- [ ] No debug interfaces enabled in production

---

## Communication Interfaces

### Serial/Debug Ports

- [ ] JTAG/SWD disabled or locked in production
- [ ] UART debug disabled or authenticated
- [ ] No sensitive data over unencrypted channels

### Network (If Connected)

- [ ] TLS 1.2+ for all network communication
- [ ] Certificate pinning for known endpoints
- [ ] Input validation on all protocol parsers
- [ ] Fuzzing performed on protocol handlers

### Bus Protocols (CAN, I2C, SPI)

- [ ] Message authentication where supported (CAN FD with MAC)
- [ ] Anomaly detection for unexpected messages
- [ ] Rate limiting on message processing

---

## Cryptography in Constrained Environments

- [ ] Hardware crypto acceleration used where available
- [ ] Constant-time implementations for secret operations
- [ ] Side-channel analysis considered (power, timing, EM)
- [ ] Entropy source validated (hardware RNG preferred)

---

## Safety-Critical Standards Compliance

### DO-178C (Avionics)

- [ ] Design Assurance Level (DAL) appropriate to failure severity
- [ ] Bi-directional traceability: Requirements ↔ Design ↔ Code ↔ Tests
- [ ] Code coverage appropriate to DAL (MC/DC for Level A)
- [ ] Formal methods applied per DO-333 where required

### ISO 26262 (Automotive)

- [ ] ASIL level determined for each function
- [ ] Freedom from interference between ASIL levels
- [ ] Diagnostic coverage for hardware faults
- [ ] Secure onboard communication (SecOC)

### IEC 62443 (Industrial)

- [ ] Security Level (SL) target defined
- [ ] Zone and conduit model implemented
- [ ] Secure development lifecycle followed

---

## Physical Security

- [ ] Tamper detection/response mechanisms
- [ ] Sensitive data zeroized on tamper
- [ ] Debug test points removed from production boards
- [ ] Chip markings don't reveal security-critical info

---

## Checklist Summary

| Category  | Items                                                    |
| :-------- | :------------------------------------------------------- |
| Memory    | Bounds checking, no dangerous functions, heap discipline |
| Real-Time | Non-blocking security, timing budgets, watchdogs         |
| Boot      | Secure boot chain, signed updates, rollback protection   |
| Comms     | Debug locked, TLS, protocol fuzzing                      |
| Crypto    | HW acceleration, constant-time, entropy                  |
| Standards | DAL/ASIL compliance, traceability                        |
| Physical  | Tamper protection, debug removal                         |
