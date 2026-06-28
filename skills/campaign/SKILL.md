---
name: campaign
description: |
  SOP for the architect-tier campaign workflow (/campaign): exhaustive
  survey, mitigation planning, tiered orchestration, and reconciliation.
  Trigger when:
  - Running a multi-workstream initiative where an expensive architect-tier
    council surveys, plans, emits worker prompts, and judges landed work.
  - Conducting production-readiness assessments that fan out into
    autonomous mitigation dispatches across model tiers.
  - Prompt contains: /campaign, campaign workflow, survey, orchestrate,
    reconcile, premise freshness, tier routing, worker IBC, scratch.
---

# Campaign Protocol v1.0: Architect-Tier Orchestration

**Absorb → Survey → Plan → Orchestrate → Dispatch ⇄ Reconcile → Close**

This workflow defines the `/campaign` execution loop for architect-class
(expensive, long-horizon) walkers coordinating heterogeneous model tiers
across a multi-workstream goal. The council's primary output genre is
not code — it is **boundary conditions for cheaper walks**, and judgment
on the work that returns.

---

## Philosophy

### The Hourglass

Expensive tokens belong at the waist, not the edges:

```
  wide:   cheap tier + human  — boundary refinement (/boundary → IBC*)
  narrow: one council pass    — exhaustive survey, planning, orchestration
  wide:   cheap tier          — disciplined worker execution (/refine, /core)
          deterministic evaluators between every layer
```

The council ingests an approved $\text{IBC}^*$ (manufactured by the
[boundary](../boundary/SKILL.md) loop), saturates its shared context through
an exhaustive multi-agent survey, and emits a graph of saturated worker
IBCs routed to the cheapest capable tier. Error-correction iterations run
in cheap space; the council re-enters only to judge and realign.

### The Plan Is a DAG of Boundary Conditions

A campaign plan is not a task list. It is a **dependency graph of IBCs
whose premises reference world state that sibling executions mutate**.
When worker P3 lands an unexpected fix, the premises baked into pending
prompts P4–P9 may now describe a world that no longer exists. An open-loop
dependency graph drifts exactly like an open-loop token walk, only at a
coarser timescale. Hence two central invariants that are examined together
at every `RECONCILE` boundary:

> **Premise Freshness:** before dispatching any pending node, re-verify
> its IBC's premises (S1 tripwires) against current `HEAD`. A stale
> premise marks the node `INVALIDATED`; its IBC is realigned before
> dispatch.

> **Goal Supremacy / Mutable DAG:** execution yields exponentially more
> context than planning — the higher-level goal reigns over the
> pre-specified DAG skeleton, not the reverse. At every `RECONCILE`
> boundary the architect seat MUST reconsider whether the DAG still serves the
> goal. DAG amendments — adding, editing, or removing nodes — are the
> **norm**, not a deviation; staying faithful to an arbitrary initial
> structure while overlooking what execution revealed is the failure mode
> this guards against. Each amendment is a new boundary — a `dag-amendment`
> the delegation table routes to the architect seat, ratified by the **head**
> before any affected node is re-dispatched.

Both checks are mechanical and cheap — they SHOULD themselves run on a cheap tier.

### The Council as Final Judge

Workers execute under their assigned discipline workflows, but
**no worker self-certifies**. Every landed changeset returns to the
council's `RECONCILE` state, which judges it with
[git-review](../git-review/SKILL.md) semantics against the worker's own
IBC: acceptance evaluators re-run, coherence checklist applied, commit
hygiene verified. The council is constantly judging whether the campaign
has proceeded correctly — that judgment, not code emission, is what the
expensive tokens buy.

### Working Set vs Flight Recorder

The campaign maintains two stores with different mutability and durability:

| Store | Role | Git status |
| :--- | :--- | :--- |
| `.scratch/<topic>/` | **Controller's live state** — the current boundary conditions, mutable and realigned as the campaign evolves | Ignored, never committed |
| `.ledger/log/` | **Flight recorder** — the trace from which the trajectory is reconstructed | Committed in the `.ledger/` subrepo |

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

The controller's session state — the live topic, phase, and context:

```yaml
# METADATA
TOPIC: "topic-slug"
STATUS: [ABSORB | CLARIFY | SURVEY | PLAN | ORCHESTRATE | DISPATCH | RECONCILE | CLOSE | HALT]

# CONTEXT
CTX:
  IBC_PATH: "path/to/approved/campaign/IBC"  # The boundary this campaign launches from
  GOAL: "Verbatim objective from the IBC"
  MODE: [INTERACTIVE | AUTONOMOUS]
  SCRATCH_PATH: ".scratch/<topic>"
```

The three persistent campaign artifacts — the findings ledger, the campaign
DAG, and the reconcile log — are **not** redefined here. Their schemas are the
locked Nickel contracts under [`ledger/contracts/`](../../ledger/contracts), and
`nickel export` over each artifact is the gate that enforces them:

| Artifact | Contract | Load-bearing invariant |
| :--- | :--- | :--- |
| Findings ledger (SURVEY) | [`findings.ncl`](../../ledger/contracts/findings.ncl) | a resolved finding (`'mitigated`/`'accepted_risk`) MUST name the `evaluator` that closed it |
| Campaign DAG (PLAN/ORCHESTRATE) | [`dag_apply.ncl`](../../ledger/contracts/dag_apply.ncl) (`Dag ∘ DagNoConflict`) | the DAG is **authored as YAML** (`<topic>/dag.yaml`) and validated via `nickel export dag.yaml --apply-contract ledger/contracts/dag_apply.ncl`; each node's `discipline` is one of `core`/`refine`/`doc`/`form`/`spec`; the graph is acyclic, referentially whole, and concurrent nodes carry disjoint `file_surface` or a `serialize` marker; contracts stay Nickel, instances are YAML |
| Reconcile log (RECONCILE) | [`reconcile_log.ncl`](../../ledger/contracts/reconcile_log.ncl) | an `'accept` judgment MUST name the `evaluator` that justified it |

The `evaluator` field and the `discipline` enum are the campaign's two
load-bearing couplings to these contracts: SURVEY and RECONCILE depend on the
Verification Dual being unforgeable (no resolution or acceptance without a named
evaluator), and ORCHESTRATE depends on `discipline` resolving to exactly one
surviving worker workflow. Read the contracts directly for field shapes; do not
restate them here.

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

CLOSE ──→ end            (final sweep passes; human accepts the report)
      └─→ RECONCILE      (final sweep finds regressions)
```

---

## States

### 1. ABSORB

Ingest the approved campaign $\text{IBC}^*$.

- **Premise Audit (boundary S2):** the council's first obligation is to
  verify the IBC's tripwires against primary sources. On contradiction,
  emit the rejection report and transition to `CLARIFY`/`HALT` — rejecting
  the frame early is a success condition, not a failure.
- Initialize `.scratch/<topic>/` and ensure `.scratch/` is git-ignored.
- Open the campaign sketch in `.ledger/log/` (flight recorder) and commit.

### 2. CLARIFY

Standard ambiguity gate. Interactive: surface to the head. Autonomous:
log a conservative assumption per [refine](../refine/SKILL.md) CLARIFY
semantics — except premise failures, which always freeze: a campaign MUST
NOT proceed from a refuted frame.

### 3. SURVEY

The expensive waist: saturate the council's shared context via exhaustive
multi-agent review of the target system.

- Fan out independent subagents in mutually isolated contexts (MBSS
  semantics from [refine](../refine/SKILL.md)) across orthogonal angles
  spanning the goal's risk surface (correctness, security, proofs/specs,
  testing, docs-drift, performance — as the goal demands).
- The **Grounded Critique Invariant** ([rules.md](../../rules.md) §4)
  applies in full: findings without reproducible evidence are filtered.
- The council synthesizes `REVIEW.md` and the `FINDINGS` ledger. The
  council reads primary sources directly (boundary S5) — subagents
  locate and excerpt; they do not paraphrase on the council's behalf.

### 4. PLAN

Derive the mitigation plan from the findings ledger.

- Decompose into nodes sized for single-discipline worker walks, with
  explicit `DEPENDS_ON` edges and `MITIGATES` mappings back to findings.
- For each node, decide what is **meaningful to verify** — the acceptance
  invariants (property statements, metamorphic relations, theorem
  statements where formal models exist). The architect seat owns the *what* of
  testing; workers implement the minutiae under TDD discipline.
- Write `PLAN.md`. In `INTERACTIVE` mode, **HALT for the head's approval** of
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
- In `INTERACTIVE` mode the head approves the routing table and prompt
  set (the boundary skill's HUMAN_DISPATCH_GATE, applied in batch).

> [!NOTE]
> **JIT per-layer IBC authoring.** Not all worker IBCs are emitted upfront.
> Layer 0 (the earliest, dependency-free layer) IBCs are authored here, at
> the initial ORCHESTRATE pass, and approved in batch. IBCs for **later
> layers** are authored JIT — at the `DISPATCH` step for that layer, with
> premises (S1) re-verified against the current integration-branch `HEAD`
> (the `tip` advanced by the preceding RECONCILE round). Authoring a
> later-layer IBC before its prerequisite nodes land means the S1 premises
> describe a world that does not yet exist; re-verifying at dispatch time is
> what makes the "Premise Freshness" invariant mechanically sound rather than
> aspirational. The routing table (`ORCHESTRATION.md`) records the node-to-
> tier mapping for all layers upfront; only the full IBC text is deferred.
> Each JIT-authored IBC still passes the WorkerIBC contract before dispatch
> (`nickel export` gate); the contract is the sufficiency check, and it runs
> at the point of authoring, not at ORCHESTRATE.

### 6. DISPATCH

Launch workers on fresh nodes whose dependencies are `ACCEPTED`. The
deterministic team-execution model — the Kahn-derived layer schedule, a
worktree per node branched from the layer's start tip, the conflict-free set
dispatched in parallel with the rest serialized, each reconciled node merged
into the shared branch and the tip advanced per layer — is the
[orchestration protocol](../../docs/orchestration-protocol.md). That protocol
is the *mechanics*; the runnable workflow that drives DISPATCH ⇄ RECONCILE as an
automaton is the **orchestration skill** (`skills/orchestration/SKILL.md`),
which packages the protocol's evaluator commands and exit-code routing into a
loop a cheap-tier runner can execute. This skill is built downstream — until it
lands, the composer drives the protocol by hand. The narrative:

- Workers run autonomously (e.g. under a `/goal`-style runner) inside
  their assigned discipline workflow, committing to the repository per
  [commit-hygiene](../commit-hygiene/SKILL.md).
- Parallel dispatch is permitted for nodes with disjoint file surfaces; the
  `DagNoConflict` contract proves the parallel set conflict-free, so the
  partition is a read of the validated DAG, not a fresh judgment. Nodes sharing
  surfaces carry a `serialize` marker and run one at a time, each isolated in
  its own worktree.
- A worker that trips a reserved predicate or rejects its boundary
  freezes and returns its report — that is the IBC working as designed. A
  surface-exceed halt and a refuted premise have deterministic resolutions
  (the surface-exceed protocol; realignment); any other reserved halt escalates
  to the head.

### 7. RECONCILE

The council re-enters to judge. The mechanical form of every step below —
its evaluator command and exit-code routing — is the
[orchestration protocol](../../docs/orchestration-protocol.md); that document
is what makes RECONCILE drivable by an automaton. For every `LANDED` node, in a
fixed (node-id) order, before merging it and before trusting the next node's
premises:

1. **Judge the changeset** with [git-review](../git-review/SKILL.md)
   semantics — `PURPOSE: verify node Pn's commits satisfy its IBC's
   acceptance criteria`. Apply the coherence checklist (scope alignment,
   atomicity, hygiene).
2. **Re-run the evaluators** named in the node's acceptance criteria
   (S4). Worker claims are not evidence; evaluator output is.
3. **Surface honesty.** Derive the node's *actual* touched set from its diff
   and reconcile it against its declared `file_surface`
   (`authorized.py --reconcile-node`). An undeclared touch routes through the
   **surface-exceed protocol** (collision-check vs concurrent surfaces →
   authorize-and-widen if disjoint, serialize if not), so the conflict
   guarantee stays honest rather than trusting a stale declaration.
4. **Bidirectional coherence-impact** — the per-landing drift gate, explicit:
   does this landing break an **already-landed** artifact, or invalidate a
   **pending** one? Machine-check it where an evaluator exists — re-run the
   orphan, link, and contract gates over the affected surface
   (`coherence_impact.sh`); for any concern no evaluator covers (meaning-level
   coherence), dispatch a decorrelated review (the Verification Dual's
   adversarial path). Breakage is caught at *this* boundary, not deferred to
   `CLOSE`.
5. **Verdict:**
   - `ACCEPT` — steps 1–4 clean and any dispatched review converged-pass.
     This is the `reconcile-accept` verdict (the architect seat's); the merge
     is a **separate** decision the delegation table routes to the
     lead-maintainer, whose **affirmative merge-consent** is required before
     the node merges and is marked `ACCEPTED` with its mitigated findings.
   - `REWORK` — an evaluator, surface, or coherence check failed: emit a
     corrective delta IBC (error feedback in cheap space) and re-dispatch;
     the node returns to `PENDING`.
   - `ESCALATE` — the fault is structural (the plan's, not the
     worker's): return to `PLAN` or `ORCHESTRATE` and realign.

Then, for **every** `PENDING` node, re-run the explicit **premise freshness
check** against the new `HEAD` (`premise_fresh.sh`, cheap tier): re-verify the
node's S1 tripwires; a flipped verdict marks the node `INVALIDATED` and its IBC
is realigned before any dispatch. Running this at *every* boundary — not once up
front — is what kills cross-node drift at the boundary instead of letting it
accumulate to `CLOSE`.

Finally: append the `RECONCILE_LOG` round, write the **sketch
checkpoint**, and commit it in the `.ledger/` subrepo. Reserved-predicate
breaches and appetite exhaustion route to the head (`HALT`).

### 8. CLOSE

> [!IMPORTANT]
> **Dual-CLOSE Invariant.** CLOSE requires two paths to close — not one.
> **(a)** the full deterministic gate suite exits green; **(b)** a
> decorrelated, context-free adversarial sufficiency review finds the
> machinery wired in and sufficient. A green gate suite is necessary but
> not sufficient: it proves execution, not coverage. The procedure is
> [docs/orchestration-protocol.md §CLOSE](../../docs/orchestration-protocol.md#close).

When all findings are `MITIGATED` or head-accepted as `ACCEPTED_RISK`
and the DAG is complete:

1. Run the full deterministic verification surface (complete test suite,
   linters, proof checkers where present) — the commit-gate scope, not
   the targeted-loop scope. **(Dual-CLOSE path (a).)**
2. Run one final adversarial sweep (MBSS) over the campaign's cumulative
   diff to catch cross-node integration drift no single worker could see.
3. **Run the sufficiency review.** **(Dual-CLOSE path (b).)** Dispatch
   decorrelated, context-free reviewers to audit whether the gate
   machinery is wired in and sufficient. Their question: "what does no
   gate check, what is defined-but-unwired, what claim is hollow?" Route
   findings to follow-up nodes or tech-debt records before acceptance.
   When reviewers do not converge on a SUFFICIENT verdict, escalate to the
   head — this is a `[HUMAN SEAM]` at CLOSE.
4. **Emit a retrospective to the flight recorder** (`.ledger/log/`) before
   presenting the report to the head. The retrospective captures the
   hard-won context that survives context loss and compaction. It MUST
   include: original goal and what actually landed; execution-model and
   intellectual-capital lessons (surprises, realignments, what the initial
   DAG missed); open watch-items or residual risks; a durability map
   (which artifacts are durable, which scratch is disposable); and a
   **`## Sufficiency Review` section** (reviewers, convergence verdict,
   and any findings routed to follow-up nodes or tech-debt records — the
   durable trace of path (b); the orchestrator's content responsibility).
   Commit in the `.ledger/` subrepo tagged `log: close <topic> retrospective`.
   The `recorder_close_check` gate enforces the structural floor: the close
   entry must exist **and** the `## Sufficiency Review` section must be
   present with non-empty content (at least one substantive line beneath
   the heading). A hollow heading fails. Content quality — genuine
   reviewers, honest convergence — is the adversarial reviewer's
   responsibility, not the gate's.
5. Produce the campaign report from `REVIEW.md` → outcomes: findings
   table with mitigation evidence, DAG execution trace, reconcile rounds,
   realignments, residual risks.
6. **HALT for the head's final acceptance.** Scratch MAY then be discarded;
   the sketch and git history carry the durable record.

---

## Prime Directives

1. **BOUNDARY_SUFFICIENCY:** The campaign launches only from a
   head-approved $\text{IBC}^*$, and every emitted worker IBC satisfies
   sufficiency conditions S1–S7. An insufficient boundary is not
   dispatched, ever.
2. **PREMISE_FRESHNESS + GOAL_SUPREMACY:** At every `RECONCILE` boundary,
   re-verify two things: (a) every pending node's premises against current
   `HEAD` (stale premise → `INVALIDATED`); (b) whether the DAG as a whole
   still serves the goal. DAG amendments are normal and head-approved —
   open-loop dispatch of a stale or goal-misaligned DAG is a protocol
   violation.
8. **RETROSPECTIVE_AT_CLOSE:** Before the head's final acceptance, emit a
   retrospective to the flight recorder (`.ledger/log/`). Every campaign's
   hard-won context — what landed vs the goal, execution-model lessons,
   open watch-items, durability map — must survive context loss. The
   retrospective is a `CLOSE` step, not an afterthought. The retrospective
   MUST include a `## Sufficiency Review` section with substantive content
   (at least one non-blank, non-heading line beneath the heading) — a
   hollow heading or absent section fails the `recorder_close_check`
   structural floor and halts CLOSE. Content quality (genuine reviewers,
   honest convergence) is the adversarial reviewer's responsibility; the
   gate enforces presence and a non-empty floor only.
9. **DUAL_CLOSE:** A CLOSE that runs only the deterministic gate suite is
   incomplete. CLOSE terminates only when BOTH (a) the full gate suite
   exits green AND (b) a decorrelated sufficiency review finds the
   machinery wired in and sufficient. A green gate proves execution; it
   cannot prove coverage. Procedure:
   [docs/orchestration-protocol.md §CLOSE](../../docs/orchestration-protocol.md#close).
3. **COUNCIL_AS_JUDGE:** No worker output is accepted without a
   `RECONCILE` judgment grounded in re-run evaluators — the `reconcile-accept`
   verdict routes to the architect seat, and the merge requires the
   lead-maintainer's affirmative consent. Worker self-certification is void.
4. **LIVING_PLAN:** `PLAN.md`, `ORCHESTRATION.md`, and pending prompts
   are living documents — realignment when reality diverges is
   mandatory, and every realignment is logged with its why.
5. **TIER_ECONOMY:** Route every node to the cheapest tier whose
   capability bounds it. The architect-tier seats do not emit code for
   worker-shaped tasks; workers do not make architecture decisions.
6. **CHECKPOINT_DURABILITY:** `.scratch/` is never committed; the sketch
   checkpoints at every reconcile boundary so resume derives from
   sketch + git alone.
7. **DELEGATED_TDD:** The architect seat specifies the invariants worth
   verifying; workers implement tests and code under their discipline's
   closed loop, baseline failure included.
