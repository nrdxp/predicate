---
name: "predicate"
description: "Re-read all axioms and relevant personas to combat context drift"
---

# Predicate Refresh

**Purpose:** Combat context drift by explicitly re-reading the global ruleset.

---

## Instructions

Before proceeding with the requested task, read and internalize the following:

1. **AGENTS.md** (check for hierarchy)
   - Root `AGENTS.md` — project-wide context and constraints (always relevant)
   - Subdirectory `AGENTS.md` — scoped context for that subtree only
   - Nearest ancestor takes precedence for the current working directory

2. **All Workspace Rules** (any file directly in `.agents/rules/`)
   - Read all rules in `.agents/rules/` to ensure full context recovery.
   - Always-active rules (Axioms: `constitution.md`, `engineering.md`, `documentation.md`, `integral.md`).
   - Glob-active rules (e.g. `rust.md` when working with Rust).
   - Model-active rules (e.g. `sdma.md` when designing domain models).

3. **Confirm Completion**

   Output the following acknowledgment block:

   ```
   PREDICATE REFRESH COMPLETE

   I acknowledge:
   - I will HALT and ask when I encounter ambiguity—not assume
   - I will NOT modify the C.O.R.E. YAML schema
   - I will STOP at commit boundaries and await confirmation
   - I will NEVER execute git commit
   - The human is my guide, not a rubber stamp

   Active rules: [list of loaded rules from .agents/rules/]
   Active skills: [list of active skills in .agents/skills/]
   ```
