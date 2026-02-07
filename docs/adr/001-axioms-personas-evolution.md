# ADR-001: Two-Tier Ruleset Architecture with Protocol Refinements

**Status:** ACCEPTED

**Date:** 2026-02-06

**Plan:** [predicate-architecture-evolution.md](../plans/predicate-architecture-evolution.md)

---

## Context

Predicate's original structure nested "fragments" under "predicates," implying subordination. In practice, both are equally important rules with different activation semantics. Additionally, agents exhibited scanning failures—missing context and reaching wrong conclusions because the protocol lacked verification checkpoints.

## Decision

### Two-Tier Ruleset Model

| Tier         | Directory          | Activation                              |
| :----------- | :----------------- | :-------------------------------------- |
| **Axioms**   | `.agent/axioms/`   | Always loaded; foundational constraints |
| **Personas** | `.agent/personas/` | On-demand; required or discretionary    |

These are **peer directories**, not nested. Both are first-class concepts.

### Protocol Refinements

1. **Structured confirmation:** Agent must echo back what axioms/personas it loaded:

   ```
   PREDICATE CONFIRMATION:
   - Axioms: [list]
   - Active Personas: [list]
   - Discretionary: [list with rationale]
   ```

2. **HALT semantics:**
   - Missing axiom → HALT (foundational failure)
   - Missing required persona → HALT, ask if proceed

3. **Workflow binding:** Workflows can declare `required_personas:` to require specific context when invoked.

### Protocol Flow

```
AGENTS.md → PREDICATE.md → Scan axioms/ + Check personas
                                ↓
                    Structured Confirmation
                                ↓
                        Begin work
```

## Consequences

### Positive

- Clear mental model: axioms are constraints, personas are context
- Verifiable scanning: confirmation output catches failures
- Flexible binding: workflows can require relevant personas

### Negative

- Breaking change: all documentation requires updates
- Terminology shift: users must learn new terms

---

## Alternatives Considered

| Alternative                   | Reason Rejected                         |
| :---------------------------- | :-------------------------------------- |
| Keep nested structure         | Implies incorrect subordination         |
| "Roles" instead of "personas" | Less declarative, too pedantic          |
| Explicit "Available" list     | Maintenance burden; implicit is cleaner |

---

## References

- Plan: [predicate-architecture-evolution.md](../plans/predicate-architecture-evolution.md)
