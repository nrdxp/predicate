# Predicate System

This document is the agent protocol for projects using [Predicate](https://github.com/nrdxp/predicate). It is **required reading** — follow the protocol below before beginning any work.

---

## § Protocol

Execute these steps in order. Each step has an implicit verification condition — if you cannot complete it, **HALT** and surface the issue.

1. **SCAN** `.agent/axioms/` — list all `.md` files found. These are **axioms**: non-negotiable foundational rules that are always active. Read each one.

2. **CHECK** `AGENTS.md` for the **Active Personas** section. These are context-specific rulesets the project requires you to load.

3. **LOAD** each active persona from `.agent/personas/`. If a required persona file is missing, **HALT** and ask the human whether to proceed.

4. **REVIEW** available personas — everything in `.agent/personas/` not already loaded. If a persona's domain matches the current task, you **may** adopt it discretionarily. Announce which persona you are adopting and why.

5. **CHECK** the current workflow (if invoked via slash command). If the workflow declares `required_personas:` in its frontmatter, load those personas. Missing workflow-required persona → **HALT**.

6. **CONFIRM** understanding by outputting a structured confirmation:

   ```
   PREDICATE CONFIRMATION:
   - Axioms: [list of axiom files found and read]
   - Active Personas: [list loaded from AGENTS.md]
   - Workflow-Required: [list loaded via required_personas: frontmatter, or "none"]
   - Discretionary: [list adopted with rationale, or "none"]
   ```

7. **BEGIN** work.

> [!CAUTION]
> **Missing axiom = foundational failure.** If `.agent/axioms/` is empty or inaccessible, do not proceed. HALT immediately.

---

## § Terminology

| Term         | Directory           | Activation                                       |
| :----------- | :------------------ | :----------------------------------------------- |
| **Axiom**    | `.agent/axioms/`    | Always active — scan and read unconditionally    |
| **Persona**  | `.agent/personas/`  | Opt-in — required by project or adopted by agent |
| **Workflow** | `.agent/workflows/` | User-triggered via slash command                 |

- **Axiom** = non-negotiable rule for the agent. The file itself can be edited by humans, but while active, the agent treats it as law.
- **Persona** = context-specific ruleset. Not a personality — a domain-specific set of constraints and idioms (e.g., "Rust persona" = Rust idioms and patterns).
- **Workflow** = a task-specific standard operating procedure, triggered via slash command (e.g., `/core`, `/plan`).

---

## § Precedence

When rules conflict across files, higher-ranked sources win:

1. `axioms/engineering.md` — highest authority
2. `axioms/integral.md` — cognitive disposition
3. `axioms/documentation.md` — writing quality
4. Personas — domain-specific rules (context-dependent, no fixed rank among them)

Within `engineering.md`, the RULE PRIORITY section governs intra-engineering conflicts (Security > User Decision > API Stability > Maintainability > Performance).

---

## § Hierarchical Configuration

The [AGENTS.md standard](https://agents.md) supports hierarchical configuration. When working in a subdirectory, check for and read any `AGENTS.md` in that directory. Subdirectory rules supplement (not replace) the root configuration.

---

## § Why

We plan carefully because we want our work to be meaningful — useful, well-structured, and worthy of the effort. Precision matters. When ambiguous, **HALT** and surface the question. The best code is no code; the best plan is the one that catches a flawed premise before execution.

The structured confirmation exists for the **agent**, not as ceremony for the human. It ensures the agent knows exactly what rules are active and catches scanning failures before they cascade into wrong conclusions.
