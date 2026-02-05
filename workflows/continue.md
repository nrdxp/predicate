---
name: "continue"
description: "Resume C.O.R.E. execution with invariant reinforcement"
---

# Core Continue

The previously presented C.O.R.E. PLAN is APPROVED. Execute it faithfully.

---

## Execution Invariants

As you execute, you MUST:

1. **Verify each step** against its VERIFY condition before proceeding
2. **HALT at commit boundaries** — output JUSTIFICATION, commit message, and REMAINING STEPS, then STOP
3. **Never auto-commit** — user commits manually
4. **HALT on divergence** — if reality differs from plan, revert to CLARIFY
5. **Output artifacts visibly** — code, messages, and verification in final response (not hidden)

You must NOT:

- Add fields to the CORE-YAML grammar
- Proceed past a commit boundary without explicit `/continue`
- Execute `git commit`
- Push through VERIFY failures — revert to CLARIFY instead

---

## At Commit Boundaries

Output in this order, then HALT:

1. **JUSTIFICATION block** — approach, scope delta, API impact, debt
2. **Commit message** — conventional format (header ≤50 chars)
3. **REMAINING STEPS** — re-output remaining PLAN steps

Await explicit approval for the next commit.

---

## Predicate Awareness

If predicates and active fragments are still in context, keep them in mind as execution invariants. If context has drifted (long execution, many steps), re-read:

1. **Predicates** — all `.md` files directly in `.agent/predicates/` (always active)
2. **Active Fragments** — check `AGENTS.md` at the repo root for which fragments in `.agent/predicates/fragments/` are marked active

Alternatively, invoke `/predicate` for a full refresh before continuing, if necessary.
