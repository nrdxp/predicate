---
name: predicate
description: |
  Protocol to re-read active skills and rulesets to combat context drift.
  Trigger when:
  - Full refresh of rule context is needed, or starting a new session.
  - Prompt contains: /predicate, reload rules, reload context, context drift.
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

2. **All Workspace Skills** (any skill under `.agents/skills/`)
   - Read all relevant skills in `.agents/skills/` to ensure full context recovery.
   - Foundational skills (`skills/constitution/SKILL.md`, `skills/engineering/SKILL.md`, `skills/documentation/SKILL.md`, `skills/integral/SKILL.md`).
   - Language skills (e.g. `rust` when working with Rust).
   - Domain skills (e.g. `sdma` when designing domain models).

3. **Confirm Completion**

   Output the following acknowledgment block:

   ```
   PREDICATE REFRESH COMPLETE

   I acknowledge:
   - I will HALT and ask when I encounter ambiguity—not assume.
   - I will NOT modify the C.O.R.E. YAML schema (except permitted CONTROL_MODE field).
   - I will STOP at commit boundaries (unless CONTROL_MODE: AUTOMATIC is active and authorized).
   - I will NEVER execute git commit without explicit authorization and passing verification.
   - The human is my guide, not a rubber stamp.

   Active skills: [list of loaded skills from .agents/skills/]
   ```