---
name: campaign
description: |
  SOP for the architect-tier campaign workflow (/campaign): exhaustive
  survey, mitigation planning, tiered orchestration, and reconciliation.
  Trigger when:
  - Running a multi-workstream initiative where an expensive architect
    model surveys, plans, emits worker prompts, and judges landed work.
  - Conducting production-readiness assessments that fan out into
    autonomous mitigation dispatches across model tiers.
  - Prompt contains: /campaign, campaign workflow, survey, orchestrate,
    reconcile, premise freshness, tier routing, worker IBC, scratch.
---

# Campaign Protocol v1.0: Architect-Tier Orchestration

**Absorb → Survey → Plan → Orchestrate → Dispatch ⇄ Reconcile → Close**

This workflow defines the `/campaign` execution loop for architect-class
(expensive, long-horizon) walkers coordinating heterogeneous model tiers
across a multi-workstream goal. The architect's primary output genre is
not code — it is **boundary conditions for cheaper walks**, and judgment
on the work that returns.

---

## Philosophy

### The Hourglass

Expensive tokens belong at the waist, not the edges:

```
  wide:   cheap tier + human  — boundary refinement (/boundary → IBC*)
  narrow: one architect pass  — exhaustive survey, planning, orchestration
  wide:   cheap tier          — disciplined worker execution (/refine, /core)
          deterministic evaluators between every layer
```

The architect ingests an approved $\text{IBC}^*$ (manufactured by the
[boundary](../boundary/SKILL.md) loop), saturates its own context through
an exhaustive multi-agent survey, and emits a graph of saturated worker
IBCs routed to the cheapest capable tier. Error-correction iterations run
in cheap space; the architect re-enters only to judge and realign.

### The Plan Is a DAG of Boundary Conditions

A campaign plan is not a task list. It is a **dependency graph of IBCs
whose premises reference world state that sibling executions mutate**.
When worker P3 lands an unexpected fix, the premises baked into pending
prompts P4–P9 may now describe a world that no longer exists. An open-loop
dependency graph drifts exactly like an open-loop token walk, only at a
coarser timescale. Hence the central invariant:

> **Premise Freshness:** before dispatching any pending node, re-verify
> its IBC's premises (S1 tripwires) against current `HEAD`. A stale
> premise marks the node `INVALIDATED`; its IBC is realigned before
> dispatch.

This check is mechanical and cheap — it SHOULD itself run on a cheap tier.

### The Architect as Final Judge

Workers execute under their assigned discipline workflows, but
**no worker self-certifies**. Every landed changeset returns to the
architect's `RECONCILE` state, which judges it with
[git-review](../git-review/SKILL.md) semantics against the worker's own
IBC: acceptance evaluators re-run, coherence checklist applied, commit
hygiene verified. The architect is constantly judging whether the campaign
has proceeded correctly — that judgment, not code emission, is what the
expensive tokens buy.

### Working Set vs Flight Recorder

The campaign maintains two stores with different mutability and durability:

| Store | Role | Git status |
| :--- | :--- | :--- |
| `.scratch/<topic>/` | **Controller's live state** — the current boundary conditions, mutable and realigned as the campaign evolves | Ignored, never committed |
| `.sketches/` | **Flight recorder** — the trace from which the trajectory is reconstructed | Committed in the sketches subrepo |

```
.scratch/<topic>/
├── REVIEW.md           # Survey report (evidence-grounded findings)
├── PLAN.md             # Mitigation plan: the campaign DAG, living
├── ORCHESTRATION.md    # Routing table: node → tier → discipline
└── prompts/
    ├── P1-<slug>.md    # Worker IBCs per templates/IBC.md
    └── ...
```

> **Checkpoint Durability Invariant:** at every `RECONCILE` boundary the
> sketch records a checkpoint sufficient to regenerate the scratch state —
> which nodes dispatched/accepted/invalidated, what realignments occurred
> and why. A crash mid-campaign may cost working files, never the
> campaign: resume MUST derive from sketch + git alone.

---

## Scope

> [!IMPORTANT]
> `/campaign` is for multi-workstream initiatives where survey, routing,
> and reconciliation across model tiers pay for themselves. A single
> well-scoped change goes straight to `/core`; a single-artifact polish
> goes to `/refine`. Do not stand up a campaign for work one disciplined
> walker can finish — the orchestration overhead is itself a token cost.

---

## Grammar

```yaml
# 1. METADATA
TOPIC: "topic-slug"
STATUS: [ABSORB | CLARIFY | SURVEY | PLAN | ORCHESTRATE | DISPATCH | RECONCILE | CLOSE | HALT]

# 2. CONTEXT
CTX:
  IBC_PATH: "path/to/approved/campaign/IBC"  # The boundary this campaign launches from
  GOAL: "Verbatim objective from the IBC"
  MODE: [INTERACTIVE | AUTONOMOUS]
  SCRATCH_PATH: ".scratch/<topic>"

# 3. FINDINGS LEDGER (populated by SURVEY)
FINDINGS:
  - ID: F1
    SEVERITY: [CRITICAL | HIGH | MEDIUM | LOW]
    STATEMENT: "Evidence-grounded finding"
    EVIDENCE: "Tool output, file:line, failing check"
    STATUS: [OPEN | PLANNED | MITIGATED | ACCEPTED_RISK]

# 4. CAMPAIGN DAG (populated by PLAN/ORCHESTRATE)
DAG:
  - ID: P1
    IBC: "prompts/P1-<slug>.md"
    TIER: "model class, e.g. flash-class worker"
    DISCIPLINE: "/refine | /core | ..."   # Exactly one (boundary S7)
    DEPENDS_ON: []                         # Upstream node IDs
    MITIGATES: [F1]                        # Findings this node addresses
    STATUS: [PENDING | DISPATCHED | LANDED | ACCEPTED | REWORK | INVALIDATED]

# 5. RECONCILE LOG (appended each reconciliation)
RECONCILE_LOG:
  - ROUND: 1
    JUDGED: { P1: [ACCEPT | REWORK | ESCALATE], ... }
    FRESHNESS: { P4: [FRESH | STALE], ... }
    REALIGNMENTS: ["What changed in PLAN/ORCHESTRATION/prompts and why"]
    CHECKPOINT_COMMIT: "sketches subrepo hash"
```

---

## State Transitions

```
ABSORB ──→ CLARIFY      (premise audit fails or ambiguity found)
       └─→ SURVEY       (IBC* premises verified, scratch initialized)

CLARIFY ─→ SURVEY        (resolved; or rejection report returned to /boundary)
        └─→ HALT         (frame rejected; boundary loop must reconsider)

SURVEY ──→ PLAN          (findings ledger complete and evidence-grounded)

PLAN ───→ ORCHESTRATE    (human approves plan in interactive mode)
     └──→ HALT           (goal unreachable within appetite; report)

ORCHESTRATE ─→ DISPATCH  (worker IBCs emitted, routing table approved)

DISPATCH ──→ RECONCILE   (one or more nodes land, or a worker freezes)

RECONCILE ─→ DISPATCH    (accepted; fresh pending nodes remain)
          ├─→ ORCHESTRATE (realignment requires new/revised worker IBCs)
          ├─→ PLAN        (structural fault: the plan itself was wrong)
          ├─→ CLOSE       (all findings MITIGATED or ACCEPTED_RISK; DAG complete)
          └─→ HALT        (reserved predicate tripped, or budget exhausted)

CLOSE ──→ REPORT/end     (final sweep passes; human accepts)
      └─→ RECONCILE      (final sweep finds regressions)
```

---

## States

### 1. ABSORB

Ingest the approved campaign $\text{IBC}^*$.

- **Premise Audit (boundary S2):** the architect's first obligation is to
  verify the IBC's tripwires against primary sources. On contradiction,
  emit the rejection report and transition to `CLARIFY`/`HALT` — rejecting
  the frame early is a success condition, not a failure.
- Initialize `.scratch/<topic>/` and ensure `.scratch/` is git-ignored.
- Open the campaign sketch in `.sketches/` (flight recorder) and commit.

### 2. CLARIFY

Standard ambiguity gate. Interactive: surface to the human. Autonomous:
log a conservative assumption per [refine](../refine/SKILL.md) CLARIFY
semantics — except premise failures, which always freeze: a campaign MUST
NOT proceed from a refuted frame.

### 3. SURVEY

The expensive waist: saturate the architect's context via exhaustive
multi-agent review of the target system.

- Fan out independent subagents in mutually isolated contexts (MBSS
  semantics from [refine](../refine/SKILL.md)) across orthogonal angles
  spanning the goal's risk surface (correctness, security, proofs/specs,
  testing, docs-drift, performance — as the goal demands).
- The **Grounded Critique Invariant** ([rules.md](../../rules.md) §5.8)
  applies in full: findings without reproducible evidence are filtered.
- The architect synthesizes `REVIEW.md` and the `FINDINGS` ledger. The
  architect reads primary sources directly (boundary S5) — subagents
  locate and excerpt; they do not paraphrase on the architect's behalf.

### 4. PLAN

Derive the mitigation plan from the findings ledger.

- Decompose into nodes sized for single-discipline worker walks, with
  explicit `DEPENDS_ON` edges and `MITIGATES` mappings back to findings.
- For each node, decide what is **meaningful to verify** — the acceptance
  invariants (property statements, metamorphic relations, theorem
  statements where formal models exist). The architect owns the *what* of
  testing; workers implement the minutiae under TDD discipline.
- Write `PLAN.md`. In `INTERACTIVE` mode, **HALT for human approval** of
  the plan before any orchestration.

### 5. ORCHESTRATE

Manufacture the worker boundaries.

- Emit one IBC per node into `prompts/`, using
  [templates/IBC.md](../../templates/IBC.md). Every worker IBC MUST
  satisfy the seven sufficiency conditions in
  [boundary](../boundary/SKILL.md) — in particular:
  - **S7 Discipline Proportion:** exactly one disciplining workflow
    (e.g. `/refine` for polish nodes, `/core` for feature nodes), with
    only the load-bearing rules inlined. A cheap walker under the refine
    loop is a powerhouse; the same walker under the full ambient rule
    mass silently drops invariants.
  - **S1 Premises:** each node's world-state assumptions stated as
    falsifiable tripwires — these become the freshness keys RECONCILE
    re-verifies.
  - **S4 Evaluators:** acceptance criteria carry their evaluator commands
    so RECONCILE can re-run them without trusting worker claims.
- Write `ORCHESTRATION.md`: the routing table mapping each node to the
  **cheapest tier whose capability bounds the task**, with rationale.
- In `INTERACTIVE` mode the human approves the routing table and prompt
  set (the boundary skill's HUMAN_DISPATCH_GATE, applied in batch).

### 6. DISPATCH

Launch workers on fresh nodes whose dependencies are `ACCEPTED`.

- Workers run autonomously (e.g. under a `/goal`-style runner) inside
  their assigned discipline workflow, committing to the repository per
  [commit-hygiene](../commit-hygiene/SKILL.md).
- Parallel dispatch is permitted for nodes with disjoint file surfaces;
  nodes sharing surfaces MUST be serialized or isolated in worktrees.
- A worker that trips a reserved predicate or rejects its boundary
  freezes and returns its report — that is the IBC working as designed.

### 7. RECONCILE

The architect re-enters as judge. For every `LANDED` node:

1. **Judge the changeset** with [git-review](../git-review/SKILL.md)
   semantics — `PURPOSE: verify node Pn's commits satisfy its IBC's
   acceptance criteria`. Apply the coherence checklist (scope alignment,
   atomicity, hygiene).
2. **Re-run the evaluators** named in the node's acceptance criteria
   (S4). Worker claims are not evidence; evaluator output is.
3. **Verdict:**
   - `ACCEPT` — mark the node `ACCEPTED`, mark mitigated findings.
   - `REWORK` — emit a corrective delta IBC (error feedback in cheap
     space) and re-dispatch; the node returns to `PENDING`.
   - `ESCALATE` — the fault is structural (the plan's, not the
     worker's): return to `PLAN` or `ORCHESTRATE` and realign.

Then, for every `PENDING` node: run the **premise freshness check**
against current `HEAD` (cheap tier). Stale nodes are `INVALIDATED` and
their IBCs realigned before any dispatch.

Finally: append the `RECONCILE_LOG` round, write the **sketch
checkpoint**, and commit it in the sketches subrepo. Reserved-predicate
breaches and appetite exhaustion route to the human (`HALT`).

### 8. CLOSE

When all findings are `MITIGATED` or human-accepted as `ACCEPTED_RISK`
and the DAG is complete:

1. Run the full deterministic verification surface (complete test suite,
   linters, proof checkers where present) — the commit-gate scope, not
   the targeted-loop scope.
2. Run one final adversarial sweep (MBSS) over the campaign's cumulative
   diff to catch cross-node integration drift no single worker could see.
3. Produce the campaign report from `REVIEW.md` → outcomes: findings
   table with mitigation evidence, DAG execution trace, reconcile rounds,
   realignments, residual risks.
4. **HALT for human final acceptance.** Scratch MAY then be discarded;
   the sketch and git history carry the durable record.

---

## Prime Directives

1. **BOUNDARY_SUFFICIENCY:** The campaign launches only from a
   human-approved $\text{IBC}^*$, and every emitted worker IBC satisfies
   sufficiency conditions S1–S7. An insufficient boundary is not
   dispatched, ever.
2. **PREMISE_FRESHNESS:** Never dispatch a pending node without
   re-verifying its premises against current `HEAD`. Open-loop dispatch
   of a stale DAG is a protocol violation.
3. **ARCHITECT_AS_JUDGE:** No worker output is accepted without a
   `RECONCILE` judgment grounded in re-run evaluators. Worker
   self-certification is void.
4. **LIVING_PLAN:** `PLAN.md`, `ORCHESTRATION.md`, and pending prompts
   are living documents — realignment when reality diverges is
   mandatory, and every realignment is logged with its why.
5. **TIER_ECONOMY:** Route every node to the cheapest tier whose
   capability bounds it. The architect does not emit code for
   worker-shaped tasks; workers do not make architecture decisions.
6. **CHECKPOINT_DURABILITY:** `.scratch/` is never committed; the sketch
   checkpoints at every reconcile boundary so resume derives from
   sketch + git alone.
7. **DELEGATED_TDD:** The architect specifies the invariants worth
   verifying; workers implement tests and code under their discipline's
   closed loop, baseline failure included.
