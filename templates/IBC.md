# IBC: [Task Name]

<!--
  IBC documents are boundary contracts produced by the /boundary refinement
  loop and consumed by the walker (model) that executes the task. They are
  the operational rendering of the seven sufficiency conditions (S1–S7) in
  skills/boundary/SKILL.md — the normative authority over this template.

  An IBC is TWO ARTIFACTS, not one: this graded markdown document (intent,
  rationale, the human-readable case) PLUS a YAML floor that mirrors it
  field-for-field. The floor is what actually gets validated —
  `ledger/contracts/worker_ibc.ncl`'s `Worker` shape composed with its
  `WorkerIBC` sufficiency gate:

    nickel export <ibc>.yaml --apply-contract ledger/contracts/worker_ibc_apply.ncl

  A worked instance that already validates cleanly lives at
  `ledger/fixtures/boundary_procedure_honest.ncl` (its `output` field) — read
  it for the literal shape rather than copying it here; embedding a second
  copy in this template would be a third artifact that can itself drift from
  the contract. Project and validate it directly:

    printf '(import "ledger/fixtures/boundary_procedure_honest.ncl").output' \
      | nickel export --apply-contract ledger/contracts/worker_ibc_apply.ncl

  Campaign worker IBCs live in .scratch/prompts/ (uncommitted working set).
  Standalone IBCs may live wherever the dispatching context requires.

  Every section below maps to a sufficiency condition AND a field of the
  floor's `Worker` record, noted in its comment. A section left empty is a
  sufficiency violation, not a formality skipped.
-->

## Metadata

<!-- Floor fields: `id`, `tier` (both NonEmptyString) and `discipline` — S7:
     exactly ONE control loop, the shared enum in discipline.ncl (core |
     refine | doc | form | spec). -->

| Field | Value |
| :--- | :--- |
| **ID** | <!-- e.g. P3, or topic slug --> |
| **Target tier** | <!-- architect \| worker — and model class, e.g. "worker / flash-class" --> |
| **Discipline** | <!-- S7: exactly ONE predicate workflow that is this walker's control loop, e.g. /refine, /core --> |
| **Depends on** | <!-- IBC IDs whose completion this dispatch assumes; drives premise freshness checks --> |

## Goal

<!-- Floor field: `goal` — a Directive: {id, statement, provenance}. The
     objective, verbatim and singular. One goal per IBC. If you need "and",
     you need two IBCs. `provenance` names the issuing authority (a Signer:
     {kind: human|agent|source|derived|unattributed, name}) — a goal set by
     the human names `{kind: human, name: ...}`. A directive closes by
     AUTHORITY, never by evidence: it carries no `backing`, `axes`, or
     `discharge` — those are category errors on a directive. -->

## Non-Goals

<!-- Floor field: `non_goals` — Array of Directives (same shape as Goal).
     Forbidden regions. Negative constraints prune more phase-space per
     token than positive goals — underinvesting here is the most common
     boundary defect. Be concrete: "Do not touch the public API surface",
     "This is not a performance task." -->

- ...

## Premises (S1)

<!-- Floor field: `premises` — Array of CLOSED claim entries
     (ledger/contracts/entry.ncl's `Entry`, narrowed by worker_ibc.ncl's
     `PremiseChecked`) — not free prose with a Check/Verified pair. Every
     assertion about the current state of the world this task relies on.
     These are the tripwires that make cheap rejection possible — and the
     freshness keys re-verified before dispatch when sibling tasks mutate
     the world.

     Each premise carries, in the floor:
       id, statement           — identity and the falsifiable claim
       assertion: claim        — a premise asserts a truth-value (never `question`)
       backing                 — corroborated | vouched | unclosed | residual
       signer: {kind, name}    — who is asserting it
       check: {command, ran, at}   -- OR --   witness: {name, at}
                                — the evidence closing it; PremiseClosed
                                  requires at least one of the two
       axes: {determined, certifiable, monotone}
                                — REQUIRED: the author's own assessment of
                                  the claim's coordinates (PremiseHasAxes) —
                                  an IBC author is obligated to assess the
                                  ground the dispatch will stand on

     See the worked example (top of this file) for a full instance.
-->

- ...

## Decision Rights (S3)

<!-- Floor fields: `delegated` and `reserved` (both Array String) carry the
     walker's calls and the human's halt predicates once a question is
     resolved into one bucket or the other. A question the refinement loop
     cannot yet resolve is carried forward as an `unknowns` entry — a
     question entry (entry.ncl's `Entry`, narrowed by worker_ibc.ncl's
     `UnknownChecked`): {id, statement, assertion: question, backing:
     unclosed, signer, discharge, closer}. `discharge` states the condition
     that would close it; `closer` names who can
     ({kind: human|agent|source, name?}). A question missing either field
     is not routable and the IBC is not sufficient. -->

### Resolved

<!-- Questions answered during boundary refinement. Evidence attached. -->

| Question | Answer | Evidence |
| :--- | :--- | :--- |
| ... | ... | ... |

### Delegated

<!-- The walker's calls (`delegated`). Genuine discretion, logged reasoning.
     For an architect-tier IBC this set MUST be non-empty
     (NO_EMPTY_DELEGATION). -->

- ...

### Reserved (Halt Predicates)

<!-- The human's calls (`reserved`). Each stated as a predicate the walker
     can evaluate: "IF mitigation requires changing a public API THEN
     freeze and report." -->

- ...

## Constraints (S4)

<!-- Floor field: `constraints` — Array of Constraint Directives:
     {id, statement, provenance, evaluator}. Every constraint names the
     strongest affordable deterministic evaluator: machine-checked proof >
     type system > property test > example test > linter > decorrelated
     adversarial review > [human: escalation only]. A constraint without an
     evaluator is an exhortation — ground it or move it to the rubric.

     Format:
     **[constraint-id]**: [BCP 14 statement]
     - **Evaluator**: [exact command or proof obligation]
     - **Provenance**: [the issuing authority]
-->

- ...

## Context Map (S5)

<!-- Floor field: `context_map` — Array String. Pointers and verbatim
     excerpts ONLY — never paraphrase. The boundary author selects; the
     walker reads primary sources directly.

     Format:
     - `path/to/file:120-180` — [why this matters, one line]
     - Quoted excerpt blocks where the exact wording is load-bearing.
-->

- ...

## Acceptance Criteria

<!-- Floor field: `acceptance` — Array of Criterion Directives:
     {id, statement, provenance, eval}. Definition of done, machine-checkable
     where possible (S4 hierarchy applies). At least one entry is REQUIRED —
     the sufficiency gate rejects zero acceptance criteria as an unbounded
     walk. For TDD-disciplined workers: the invariants to encode as tests,
     with the expected baseline failure (ΔE₀ ≠ 0) stated. The architect
     specifies WHAT is meaningful to verify; the worker implements the test
     minutiae. -->

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

<!-- Floor fields: `load_bearing` and `plastic` (both Array String).
     Partition the clauses of this contract:

     Load-bearing (amendment returns to the human):
     - [typically: Goal, Non-Goals, Reserved predicates, ...]

     Plastic (walker may revise with logged justification):
     - [typically: tactics, sequencing, internal structure, ...]

     Amendments to plastic clauses are logged where the dispatching loop
     reads them (campaign RECONCILE, or the active sketch). -->

- **Load-bearing:** ...
- **Plastic:** ...
