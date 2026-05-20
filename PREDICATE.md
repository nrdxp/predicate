# Predicate System

This document is the agent protocol for projects using [Predicate](https://github.com/nrdxp/predicate). It is **required reading** — follow the protocol below before beginning any work.

---

## § Constitution

The constitutional rule ([`rules/constitution.md`](rules/constitution.md)) is the foundational root of the entire Predicate system. It governs when rules conflict, when situations are novel, or when no specific rule applies. All other rules, skills, and workflows operate under its authority.

---

## § Protocol

Execute these steps in order. Each step has an implicit verification condition — if you cannot complete it, **HALT** and surface the issue.

1. **SCAN** `.agents/rules/` — list all `.md` files found. Read the always-active rules (Axioms: `constitution.md`, `engineering.md`, `documentation.md`, `integral.md`).

2. **DETERMINE** which glob-active rules apply to the files in scope (e.g. `rust.md` for Rust files, `python.md` for Python files).

3. **CHECK** for model-active rules that match the current task type (e.g. `sdma.md` for domain modeling, `planning.md` for plans).

4. **SCAN** `.agents/skills/` for custom skills (e.g. `depmap/`, `security-audit/`). Read their `SKILL.md` instructions if their capabilities are relevant to the task.

5. **CONFIRM** understanding by outputting a structured confirmation:

   ```
   PREDICATE CONFIRMATION:
   - Always-Active Rules: [list of loaded axioms]
   - Match-Active Rules: [glob/model rules loaded with reason]
   - Triggered Skills: [list of skills relevant/loaded]
   - Workflow: [name of slash command invoked, or "none"]
   ```

6. **BEGIN** work.

> [!CAUTION]
> **Missing rules = foundational failure.** If `.agents/rules/` is empty or inaccessible, do not proceed. HALT immediately.

---

## § Terminology

| Term         | Directory            | Activation                                                |
| :----------- | :------------------- | :-------------------------------------------------------- |
| **Rule**     | `.agents/rules/`     | Dynamic (always, glob, or model-activated rules)          |
| **Skill**    | `.agents/skills/`    | Semantic — action/capability packages with instructions/scripts |
| **Workflow** | `.agents/workflows/` | User-triggered via slash commands (e.g. `/core`, `/plan`) |

- **Rule** = non-negotiable instruction or constraint for the agent (includes axioms and coding styles).
- **Skill** = encapsulated capabilities (e.g. tools, helper scripts, and instructions) triggered semantically by the model.
- **Workflow** = a task-specific standard operating procedure, triggered via slash command (e.g., `/core`, `/plan`).

---

## § Precedence

When rules conflict across files, higher-ranked sources win:

1. `rules/constitution.md` — foundational authority (the Constitution)
2. `rules/engineering.md` — procedural authority
3. `rules/integral.md` — cognitive disposition
4. `rules/documentation.md` — writing quality
5. Glob/Model Rules — domain-specific rules (context-dependent, no fixed rank among them)

Within `engineering.md`, the RULE PRIORITY section governs conflicts (Security > User Decision > API Stability > Maintainability > Performance).

---

## § Hierarchical Configuration

The [AGENTS.md standard](https://agents.md) supports hierarchical configuration. When working in a subdirectory, check for and read any `AGENTS.md` in that directory. Subdirectory rules supplement (not replace) the root configuration.

---

## § Why

We plan carefully because precision matters. When ambiguous, **HALT** and surface the question. The best code is no code; the best plan is the one that catches a flawed premise before execution.

The structured confirmation exists for the **agent**, not as ceremony for the human. It ensures the agent knows exactly what rules are active and catches scanning failures before they cascade into wrong conclusions.

