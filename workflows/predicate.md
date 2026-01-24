---
name: "Predicate Refresh"
description: "Re-read global rules and relevant fragments"
trigger: "/predicate"
---

# Predicate Refresh

**Purpose:** Combat context drift by explicitly re-reading the global ruleset.

---

## Instructions

Before proceeding with any task, read and internalize the following:

1. **AGENTS.md** (if present at project root)
   - Project-specific context and constraints

2. **Global Predicate** (`.agent/predicates/global.md`)
   - Core engineering principles
   - Error handling requirements
   - API stability rules
   - Documentation standards

3. **Relevant Fragments** (in `.agent/predicates/fragments`, based on current task)
   - Language-specific: `go.md`, `rust.md`, `typescript.md`
   - Tooling: `depmap.md`

---

## Checklist

After reading, confirm understanding of:

- [ ] Current project constraints from AGENTS.md
- [ ] Error handling and panic policies
- [ ] API stability requirements (pre/post 1.0)
- [ ] Documentation, testing and commit standards
- [ ] Language-specific idioms for this task

---

## Chaining

This workflow is designed to chain with others:

```
/predicate + /core
```

Use `/predicate` first to refresh context, then `/core` for structured execution.
