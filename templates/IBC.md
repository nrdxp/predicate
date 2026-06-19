# IBC: [Task Name]

<!--
  IBC documents are boundary contracts produced by the /boundary refinement
  loop and consumed by the walker (model) that executes the task. They are
  the operational rendering of the seven sufficiency conditions (S1–S7) in
  skills/boundary/SKILL.md — the normative authority over this template.

  Campaign worker IBCs live in .scratch/prompts/ (uncommitted working set).
  Standalone IBCs may live wherever the dispatching context requires.

  Every section maps to a sufficiency condition, noted in its comment.
  A section left empty is a sufficiency violation, not a formality skipped.
-->

## Metadata

| Field | Value |
| :--- | :--- |
| **ID** | <!-- e.g. P3, or topic slug --> |
| **Target tier** | <!-- architect \| worker — and model class, e.g. "worker / flash-class" --> |
| **Discipline** | <!-- S7: exactly ONE predicate workflow that is this walker's control loop, e.g. /refine, /core --> |
| **Depends on** | <!-- IBC IDs whose completion this dispatch assumes; drives premise freshness checks --> |

## Goal

<!-- The objective, verbatim and singular. One goal per IBC. If you need
     "and", you need two IBCs. -->

## Non-Goals

<!-- Forbidden regions. Negative constraints prune more phase-space per
     token than positive goals — underinvesting here is the most common
     boundary defect. Be concrete: "Do not touch the public API surface",
     "This is not a performance task." -->

- ...

## Premises (S1)

<!-- Every assertion about the current state of the world this task relies
     on. Each premise MUST be falsifiable and name its check. These are the
     tripwires that make cheap rejection possible — and the freshness keys
     re-verified before dispatch when sibling tasks mutate the world.

     Format:
     **[premise-id]**: [Falsifiable statement]
     - **Check**: [exact command, file:line, or document section]
     - **Verified**: [date/commit + evidence, or UNVERIFIED]
-->

- ...

## Decision Rights (S3)

### Resolved

<!-- Questions answered during boundary refinement. Evidence attached. -->

| Question | Answer | Evidence |
| :--- | :--- | :--- |
| ... | ... | ... |

### Delegated

<!-- The walker's calls. Genuine discretion, logged reasoning. For an
     architect-tier IBC this set MUST be non-empty (NO_EMPTY_DELEGATION). -->

- ...

### Reserved (Halt Predicates)

<!-- The human's calls. Each stated as a predicate the walker can evaluate:
     "IF mitigation requires changing a public API THEN freeze and report." -->

- ...

## Constraints (S4)

<!-- Every constraint names the strongest affordable deterministic
     evaluator: machine-checked proof > type system > property test >
     example test > linter > decorrelated adversarial review >
     [human: escalation only]. A constraint without an
     evaluator is an exhortation — ground it or move it to the rubric.

     Format:
     **[constraint-id]**: [BCP 14 statement]
     - **Evaluator**: [exact command or proof obligation]
-->

- ...

## Context Map (S5)

<!-- Pointers and verbatim excerpts ONLY — never paraphrase. The boundary
     author selects; the walker reads primary sources directly.

     Format:
     - `path/to/file:120-180` — [why this matters, one line]
     - Quoted excerpt blocks where the exact wording is load-bearing.
-->

- ...

## Acceptance Criteria

<!-- Definition of done, machine-checkable where possible (S4 hierarchy
     applies). For TDD-disciplined workers: the invariants to encode as
     tests, with the expected baseline failure (ΔE₀ ≠ 0) stated. The
     architect specifies WHAT is meaningful to verify; the worker
     implements the test minutiae. -->

- ...

## Rejection Clause (S2)

<!-- Rejecting this frame is a success condition. The walker's first
     obligation is a premise audit against the tripwires above. On failure,
     emit and freeze:

     REJECTION REPORT
     - PREMISE: [id that failed]
     - EVIDENCE: [refuting observation — command output, file:line]
     - RECONSIDER: [what the boundary loop should revisit]
-->

This boundary MAY be rejected. Rejection with evidence is a deliverable,
not a failure.

## Amendment Protocol (S6)

<!-- Partition the clauses of this contract:

     Load-bearing (amendment returns to the human):
     - [typically: Goal, Non-Goals, Reserved predicates, ...]

     Plastic (walker may revise with logged justification):
     - [typically: tactics, sequencing, internal structure, ...]

     Amendments to plastic clauses are logged where the dispatching loop
     reads them (campaign RECONCILE, or the active sketch). -->

- **Load-bearing:** ...
- **Plastic:** ...
