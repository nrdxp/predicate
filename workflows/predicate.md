---
name: "predicate"
description: "Re-read all predicates and relevant fragments to combat context drift"
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

2. **All Predicates** (any file directly in `.agent/predicates/`)
   - Currently: `engineering.md` — core engineering principles
   - Error handling requirements
   - API stability rules
   - Documentation standards
   - **Read all files in this directory** — they are all always-active

3. **Active Fragments** (in `.agent/predicates/fragments/`)
   - Check AGENTS.md for which fragments are marked "active"
   - Only load fragments relevant to the current request
   - Example: A README update doesn't require loading the Rust fragment even when active

4. **Confirm Completion**

   Output the following acknowledgment block:

   ```
   PREDICATE REFRESH COMPLETE

   I acknowledge:
   - I will HALT and ask when I encounter ambiguity—not assume
   - I will NOT modify the C.O.R.E. YAML schema
   - I will STOP at commit boundaries and await confirmation
   - I will NEVER execute git commit
   - The human is my guide, not a rubber stamp

   Active predicates: [list from predicates/]
   Active fragments: [list from AGENTS.md]
   ```
