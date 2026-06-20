---
name: orchestration
description: |
  Runnable driver for the deterministic campaign-execution protocol — the
  automaton that takes a validated campaign DAG to a correctly merged branch.
  Trigger when:
  - A campaign has a validated DAG + worker IBCs and the architect (or a
    cheap-tier runner) must DRIVE dispatch ⇄ reconcile as a loop rather than
    by hand.
  - Resuming a partially-executed campaign from its git history + sketch
    checkpoint after a halt or crash.
  - Prompt contains: /orchestrate, orchestration, drive the DAG, run the
    campaign, layer schedule, reconcile-and-merge, resume campaign.
---

# Orchestration: Driving the Campaign Execution Protocol

`/orchestrate` is the **runnable layer** that executes
[`docs/orchestration-protocol.md`](../../docs/orchestration-protocol.md) over a
live validated DAG. The protocol document is the **spec** — the exact procedure,
the exit-code routing, the four `[HUMAN SEAM]`s. This skill does not restate that
procedure; it *lifts it to a state machine a runner walks* and wires its abstract
steps to concrete repo commands. Where the spec says "assert the structural gate
exits 0," this skill says which command, with which arguments, and what each exit
code branches to.

It slots between [campaign](../campaign/SKILL.md)'s §DISPATCH and §RECONCILE —
the two steps campaign already delegates *by reference* to the protocol. Until
this skill is invoked, the architect drives the protocol by hand; invoked, it
drives DISPATCH ⇄ RECONCILE as a loop a cheap-tier runner can replay.

> [!IMPORTANT]
> **Non-duplication pointer.** This skill does **not** re-specify campaign
> mechanics. [campaign/SKILL.md §6 DISPATCH and §7 RECONCILE](../campaign/SKILL.md)
> own the *narrative* (what the architect decides, the tier routing, the worker
> IBC contract); [docs/orchestration-protocol.md](../../docs/orchestration-protocol.md)
> owns the *deterministic procedure* (the pseudocode + exit-code rules). This
> skill is strictly the **driver**: it names protocol steps and sequences their
> commands. If you find yourself explaining *why* a step exists or *how an
> architect judges*, you have left orchestration space — that prose lives in
> campaign and the protocol, link to it.

---

## Inputs (the driver's contract)

The protocol declares the inputs an orchestrator needs
([protocol §"inputs"](../../docs/orchestration-protocol.md), lines 19-24). This
skill makes them an explicit, **parameterized** contract — the protocol's
pseudocode and `ledger/derive/layers.ncl` reference the *project-state* DAG by a
fixed path; a driver run binds that path, it does not hardcode it.

| Parameter | Binds | Default (this repo) |
| :--- | :--- | :--- |
| `DAG` | the validated DAG artifact — must pass `ledger/contracts/dag.ncl` (`Dag ∘ DagNoConflict`) | `.ledger/state/dag.ncl` |
| `LAYERS` | the Kahn-layering derivation that imports `DAG` | `ledger/derive/layers.ncl` |
| `PLAN` | the campaign plan (node intents, tier routing) | the campaign working set's `PLAN.md` |
| `PROMPTS` | the per-node worker IBCs handed at DISPATCH | `prompts/<node-id>-*.md` |
| `TOPIC` | the campaign topic — names the integration branch `campaign/<TOPIC>` and the sketch | the active flight-recorder slug |
| `MODE` | `AUTONOMOUS` (resolve seams by policy / escalate) or `INTERACTIVE` (surface seams to the human) | `INTERACTIVE` |

`layers.ncl` imports `DAG` internally; pointing the driver at a different DAG
(e.g. a demonstration graph) means binding the import that `LAYERS` resolves, not
editing the derivation. The driver never improvises a schedule — it `nickel
export`s `LAYERS` and reads the result.

### Where the driver lives — the flight-recorder convention (machine-known)

The driver must LOCATE its own recorder and REACH neighboring context. The
convention is fixed, so both are mechanical, not discovered:

- **One sketch/ledger repo per org/project-umbrella.** The recorder is a git
  repo (here `.ledger/`, a nested repo) — not loose files.
- **Each project's history is a distinct branch** of that repo. The active
  campaign's project is the **current branch** of the recorder
  (`git -C <recorder> branch --show-current`; in this repo, the branch named
  for the project umbrella).
- **Sibling-project context is sibling branches.** A driver reaches "neighboring
  context" — a related project under the same umbrella — by reading another
  branch of the same recorder (`git -C <recorder> log <sibling-branch> -- log/`),
  never by leaving the repo or guessing paths.
- **Flight-recorder files live under `log/`** of the recorder; project-state
  artifacts (the DAG, reconcile log) under `state/`.

This lets the driver resolve its recorder, its branch, and its siblings by query
— and lets it *enforce* the convention (a campaign that writes loose sketch files
outside the recorder repo is malformed).

---

## State

The orchestrator's entire state is reconstructable from git + the sketch
checkpoint (rules.md §5; [protocol §State](../../docs/orchestration-protocol.md)).
Per node: `STATUS ∈ {PENDING, DISPATCHED, LANDED, ACCEPTED, REWORK, INVALIDATED}`,
its `worktree` and `branch`. Globally: `shared_branch` (the integration branch),
`tip` (the commit the current layer branches from), `layers` (the derived Kahn
schedule). No state lives only in the runner's memory — every transition lands in
git or the sketch.

### Resume = log-first temporal hygiene

Resuming a partial campaign is **reconstruction, not recall** (rules.md §5,
sharpened for episodic memory). The procedure is **log-first** and it is a hard
rule, not a convenience:

1. **The git log of the recorder is the index — the timeline.** Read
   `git -C <recorder> log --oneline -- log/` and the live `git log` (project
   tree). The log says *what happened, when, with what status* — which layers
   landed, which nodes are ACCEPTED, where the run halted.
2. **Open ONLY the active campaign's sketch.** From the log, identify the single
   in-flight episode (the campaign matching `TOPIC` / the current branch) and
   full-read *that* sketch alone. Reconstruct `STATUS`, `tip`, `shared_branch`,
   and the RECONCILE_LOG cursor from it + git.
3. **Never exhaustively read prior sketches.** A *completed* campaign's flight
   recorder reads as in-flight to a naive walker — absorbing a finished goal's
   sketch as if it were live is a **context-pollution defect**. The log metadata
   *gates* whether a sketch is even opened: a sketch whose log shows it CLOSED is
   an index entry, not working context. Only the in-flight episode is loaded.

The log is the map; exactly one sketch is the territory. (Prime Invariant 5,
"reconstruct, don't recall.")

---

## The driver state machine

The protocol's pseudocode (`DRIVE` / `RUN_LAYER` / `RECONCILE_AND_MERGE` /
`SURFACE_EXCEED` / `CLOSE`) lifts to a state machine: each protocol step is a
state, each exit-code rule is a transition. The runner walks the table; it never
chooses the next action — the table + the exit code compute it.

| State | Lifts (protocol) | Action (the wired command) | Transition |
| :--- | :--- | :--- | :--- |
| `DERIVE` | `DRIVE` head, "Derived schedule" | `nickel export DAG` (structural gate); then `nickel export LAYERS` → `{layer_count, layers}` | export rc≠0 → **HALT** (the DAG is malformed; not a driver decision). rc 0 → create `shared_branch` from HEAD, `tip := HEAD`, `k := 0` → `RUN_LAYER` |
| `RUN_LAYER` | `RUN_LAYER` step 1 (`PARTITION`) | read `layers[k]`; split into `serial` (nodes with `serialize=true`) and `parallel := layer \ serial` — a *read of the validated DAG*, not a fresh conflict computation (`DagNoConflict` already proved the parallel set disjoint) | → `DISPATCH` for the parallel set |
| `DISPATCH` | `RUN_LAYER` step 2, `DISPATCH` | per node: `git worktree add .scratch/worktrees/<id> -b node/<id> <base>`; hand the worker ONLY `PROMPTS/<id>-*.md` + its discipline; `STATUS := DISPATCHED` | all dispatched → `AWAIT` |
| `AWAIT` | `RUN_LAYER` step 2, `AWAIT` | workers run autonomously, commit in their worktree under their discipline's commit gate, never push; collect each return | a worker FREEZE (surface-exceed) → `SURFACE_EXCEED`; FREEZE (refuted premise) → `REALIGN`; any other reserved halt → **[HUMAN SEAM]**; all returned → `RECONCILE` |
| `SURFACE_EXCEED` | `SURFACE_EXCEED` | `authorized.py --collision-check --path <req> --against-surfaces <concurrent surfaces>` | rc 0 (WIDEN) → widen node surface, re-export DAG (must pass `Dag ∘ DagNoConflict`), resume worker → `AWAIT`. rc 3 (SERIALIZE) → mark `serialize=true`, re-export, re-schedule into `serial` → `RUN_LAYER` |
| `RECONCILE` | `RECONCILE_AND_MERGE` (1)-(5) | for each LANDED node in **node-id order**, run the boundary checks (below); compute `VERDICT` | `ACCEPT` → `MERGE`; `REWORK` → emit corrective delta IBC, re-dispatch from current tip, `STATUS := PENDING` → `DISPATCH`; `ESCALATE` → `REALIGN` or **[HUMAN SEAM]** |
| `MERGE` | `RECONCILE_AND_MERGE` (5) ACCEPT | `git merge --no-ff node/<id>` into `shared_branch`; `STATUS := ACCEPTED`; mark mitigated findings | → `CHECKPOINT` |
| `BOUNDARY` | `RECONCILE` (3)+(4) **at the layer edge** | the **cumulative-diff coherence boundary check** (below): orphan gate for every cut/renamed workflow + `coherence_impact.sh` over the layer's cumulative diff; premise-freshness for every PENDING node | machine-check rc 1 → `REWORK` the offending node. rc 0 → advance |
| `CHECKPOINT` | `RECONCILE_AND_MERGE` (6) | append a RECONCILE_LOG round (judged verdicts, freshness, realignments) to the active sketch; commit it in the recorder (`git -C <recorder> commit`) | more nodes in layer → `RECONCILE`; layer done → `BOUNDARY`; `BOUNDARY` clean and `k+1 < layer_count` → `tip := shared_branch HEAD`, `k++` → `RUN_LAYER`; last layer → `CLOSE` |
| `REALIGN` | `REALIGN` | rewrite the node's premises/surface to current HEAD; if topology/surfaces change, re-export DAG + LAYERS (schedule may change); `STATUS := PENDING`; log it | → `DISPATCH` (or `RUN_LAYER` if the schedule changed) |
| `CLOSE` | `CLOSE` | assert every finding MITIGATED/accepted + every node ACCEPTED; run the full deterministic surface over `shared_branch`; ONE final decorrelated MBSS sweep over the cumulative diff; produce the campaign report | → **[HUMAN SEAM]**: HALT for human final acceptance + any push |

`sort` is node-id order throughout: a fixed reconcile order makes the run
**replayable** — re-running from a checkpoint reproduces the same sequence.

### RECONCILE — the per-node boundary checks (the wired commands)

For each LANDED node (in node-id order), the `RECONCILE` state runs, in order
([protocol §RECONCILE_AND_MERGE](../../docs/orchestration-protocol.md)):

```bash
# (1) JUDGE THE CHANGESET — the worker's self-report is not evidence.
#     Re-run the evaluators the node's IBC names in its acceptance criteria
#     against its worktree. Any evaluator non-zero -> VERDICT := REWORK.

# (2) SURFACE HONESTY — derive the actual touched set, reconcile vs declared.
touched=$(git -C .scratch/worktrees/<id> diff --name-only <base>..HEAD)
python3 ledger/gate/authorized.py --dag <exported-DAG.json> \
    --reconcile-node <id> $(printf -- '--path %s ' $touched)
#   rc 0 -> stayed within declared surface
#   rc 1 -> undeclared touches: run SURFACE_EXCEED on each before proceeding

# (3) BIDIRECTIONAL COHERENCE-IMPACT — does this landing break landed/pending?
bash ledger/gate/coherence_impact.sh <repo-root> [--removed <workflow> ...]
#   rc 1 -> INCOHERENT (a machine-check failed): VERDICT := REWORK
#   rc 0 -> machine-surface coherent; record any decorrelated-review DISPATCH
#           lines and their converged verdict before ACCEPT (adversarial path)

# (4) PREMISE-FRESHNESS — re-verify EVERY pending node against the new HEAD.
for p in <pending nodes>; do
  bash ledger/gate/premise_fresh.sh <p-id> <p's tripwire spec>
  #   rc 1 -> p INVALIDATED: REALIGN p's IBC before it dispatches
  #   rc 0 -> p stays FRESH
done

# (5) VERDICT: ACCEPT (1-4 clean, reviews converged) -> MERGE; else REWORK/ESCALATE.
```

### BOUNDARY — semantic coherence over the cumulative diff (not just file-surface)

> [!IMPORTANT]
> **File-surface disjointness ≠ semantic independence.** `DagNoConflict` proves
> the parallel set's *file surfaces* are disjoint — it cannot see that a node's
> **cut or rename** orphaned a reference living in a *surviving* file owned by
> nobody in this layer. This campaign learned it the hard way: removing a
> workflow left dangling references the conflict gate was structurally blind to,
> and they surfaced at CLOSE instead of at a boundary. So the per-layer
> `BOUNDARY` state runs a **semantic/reference-coherence gate over the layer's
> cumulative diff**, for the campaign's whole cut-set — not merely the per-node
> surface honesty of RECONCILE step (2).

At each layer edge, before advancing the tip, `BOUNDARY` runs:

```bash
# orphan gate: for EVERY workflow this layer removed or renamed, no surviving
# authoritative file may reference it as if live.
bash gates/check_orphans.sh <repo-root> <removed-or-renamed-workflow>...
#   rc 1 -> orphan refs: REWORK the node whose cut left the dangling ref

# coherence-impact over the LAYER's cumulative diff (contract + orphan + links),
# naming the layer's cut-set so backward-breakage is caught at the boundary.
bash ledger/gate/coherence_impact.sh <repo-root> --removed <cut-1> --removed <cut-2> ...
#   rc 1 -> a machine-check failed over the cumulative surface: REWORK
#   rc 0 -> the layer is semantically coherent; advance the tip
```

This is a **boundary** gate (cumulative diff, whole cut-set), not merely the
per-node check — it catches cross-node orphaning a single node's reconcile
cannot see. Because index-sensitive evaluators give false failures while a
worker has uncommitted changes, `BOUNDARY` runs only at a **quiescent layer
edge** (all of this layer's worktrees merged or idle).

---

## Outputs (the driver's deliverables)

- A merged `campaign/<TOPIC>` integration branch — every ACCEPTED node merged
  `--no-ff`, in layer-then-node-id order, branched from the advancing tip.
- An appended **RECONCILE_LOG** in the recorder (`state/reconcile_log.ncl` /
  the sketch): one round per boundary — judged verdicts, freshness results,
  realignments, the gate that justified each ACCEPT.
- **Sketch checkpoints** committed in the recorder after every reconcile: a
  crash resumes from sketch + git alone.
- A **CLOSE report** (the campaign report from REVIEW.md → outcomes) plus the
  final MBSS sweep verdict — produced at CLOSE, withheld of any push.

---

## The hermes seam — AUTONOMOUS vs INTERACTIVE

This skill carries the autonomy *seam* as an abstraction point; it is **not** a
programmatic hermes engine (out of scope). The protocol marks exactly four
`[HUMAN SEAM]`s ([protocol §automatability boundary](../../docs/orchestration-protocol.md));
everything else is deterministic-or-dispatched. At each seam, `MODE` decides:

| Seam | Where (state) | `AUTONOMOUS` | `INTERACTIVE` |
| :--- | :--- | :--- | :--- |
| Final acceptance + push | `CLOSE` | resolve-by-policy is **forbidden** — a release is a sovereignty decision; HALT and escalate regardless | HALT; surface the CLOSE report; the human accepts + pushes (agents never push — rules.md §3) |
| Non-resolvable reserved halt | `AWAIT`/`DISPATCH` | escalate to the human (a reserved predicate is, by definition, a human call) | surface the worker's freeze report |
| Decision-rights realignment | `RECONCILE`/`REALIGN` | resolve only if inside the IBC's declared sovereignty gates; else escalate | surface the realignment question |
| Non-converging adversarial review | `RECONCILE` step (3) | escalate (the dual escalates to human when decorrelated reviewers do not converge — rules.md §1) | surface the divergence |

Push and final acceptance are **never** resolved by policy in either mode:
remotes belong to the human (rules.md §3). The other three seams resolve by
policy in `AUTONOMOUS` *only when the call is inside a declared sovereignty
gate*, and surface in `INTERACTIVE`.

---

## Prior art (OSR1)

The worktree-isolated, dependency-layered, merge-at-boundary execution pattern
this driver implements is a well-established production pattern, not a novelty.
The grounding references are recorded in the campaign's active flight recorder
([`.ledger/log/2026-06-20-predicate-consolidation.md`](../../.ledger/log/2026-06-20-predicate-consolidation.md),
the OSR1 prior-art block) per the
[Outward-Search Reflex](../../ambient.md) and the [prior-art](../prior-art/SKILL.md)
procedure: parallel `make -j` and Apache Airflow (DAG-derived independent units
run concurrently, dependents wait on upstreams) anchor the layering; Bazel's
per-action `execroot/` sandbox and `git-worktree` (one repo, many isolated
working trees from a common object store) anchor the per-unit isolation. The
driver's contribution is binding that pattern to git worktrees as the isolation
primitive and the Verification Dual's gates as the merge-boundary check (the
prior art integrates by artifact, not by a coherence-gated `--no-ff` merge).

---

## See also

- [docs/orchestration-protocol.md](../../docs/orchestration-protocol.md) — the
  **spec** this skill drives (packaged-as note there points back here).
- [campaign/SKILL.md](../campaign/SKILL.md) — the architect-tier workflow whose
  §DISPATCH/§RECONCILE this skill makes runnable (the non-duplication anchor).
- the gate scripts the states name: `ledger/gate/authorized.py`,
  `ledger/gate/coherence_impact.sh`, `ledger/gate/premise_fresh.sh`,
  `gates/check_orphans.sh`.
