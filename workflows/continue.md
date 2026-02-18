---
name: "continue"
description: "Resume C.O.R.E. execution with invariant reinforcement"
required_personas:
  - planning
---

# Core Continue

The previously presented C.O.R.E. PLAN is APPROVED. Execute it faithfully.

---

## Execution Invariants

As you execute, you MUST:

1. **Verify each step** against its VERIFY condition before proceeding
2. **HALT at commit boundaries** — output JUSTIFICATION, commit message, and REMAINING STEPS, then STOP
3. **Never auto-commit** (`engineering.md` §11) — user commits manually
4. **HALT on divergence** — if reality differs from plan, revert to CLARIFY
5. **Output artifacts visibly** — code, messages, and verification in final response (not hidden)
6. **Update and commit sketch** — per the planning persona's Sketch Commit Discipline and Lifecycle Journal sections

You must NOT:

- Add fields to the CORE-YAML grammar
- Proceed past a commit boundary without explicit `/continue`
- Execute `git commit`
- Push through VERIFY failures — revert to CLARIFY instead
- Skip sketch updates at commit boundaries — the sketch is the decision record

---

## At Commit Boundaries

Output in this order, then HALT:

1. **Adversarial self-review** — before presenting, review your diff as a hostile reviewer. Check for:
   - **Code quality:** missed edge cases, wrong assumptions, unintended behavioral changes, silent regressions
   - **Reasoning quality:** did I accept a premise I should have questioned? Did I implement what the user asked without verifying it's what they need?

   If you find issues, fix them before proceeding.
2. **REVIEW block** — structured output of self-review findings (SCORE, FINDINGS with SEVERITY/ACTION/DETAIL). Any `DEFERRED` findings must populate JUSTIFICATION.DEBT.
3. **Sketch update** — append execution notes to `.sketches/[topic].md`, then `git add` and `git commit` in the `.sketches/` subrepo. Do this while execution context is freshest.
4. **JUSTIFICATION block** — approach, scope delta, API impact, debt
5. **Commit message** — [conventional format](https://www.conventionalcommits.org) (header ≤50 chars)
6. **REMAINING STEPS** — re-output remaining PLAN steps

Await explicit approval for the next commit.

---

## Context Awareness

If context has drifted (long execution, many steps), review these in order:

1. **Plan** — re-read `docs/plans/[topic].md` for current goals and phases
2. **Sketch** — if available at `.sketches/[topic].md`, review for decision history and execution notes
3. **ADR** — check `docs/adr/` for relevant architectural decisions
4. **Axioms** — all `.md` files directly in `.agent/axioms/` (always active)
5. **Active Personas** — check `AGENTS.md` for which personas in `.agent/personas/` are marked active

> [!TIP]
> Sketches contain the full thought chain: ideation, planning, and execution notes. If you're unsure why a decision was made, the sketch is the first place to look. Use `/git-review` on `.sketches/` to see how decisions evolved.

Alternatively, invoke `/predicate` for a full refresh before continuing.
