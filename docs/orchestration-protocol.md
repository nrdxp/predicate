# Orchestration Protocol — The Machine-Executable Execution Layer

The [campaign skill](../skills/campaign/SKILL.md) specifies *what* the execution
layer does in prose. This document specifies it *deterministically*: the exact
procedure an orchestrator runs to drive a validated campaign DAG to a correctly
merged branch. The procedure runs identically whether a human, an agent, or an
external tool drives it — that identity is the operational meaning of the
campaign's automatability acceptance test.

> This procedure is packaged as the runnable
> [`skills/orchestration`](../skills/orchestration/SKILL.md) skill, which lifts
> the pseudocode below to a state-machine table and wires its steps to concrete
> repo commands. This document remains the spec; the skill is the driver.

"Machine-executable" constrains the **protocol**, not every check it dispatches.
The protocol is deterministic: given a DAG and a current state, the next action
(what to run, what to dispatch, when) is computed, never improvised. Some
dispatched checks return *soft* verdicts — the Verification Dual's adversarial
path closes conditions no evaluator can decide. Dispatching that review is
itself a deterministic step; only the review's verdict is soft. Every point
where an irreducible human judgment remains is marked **[HUMAN SEAM]**: those,
and only those, are where an autonomous driver halts for a person.

The inputs an orchestrator needs, and nothing more:

- a YAML DAG instance (`dag.yaml`) validated against `ledger/contracts/dag.ncl` (`Dag` ∘ `DagNoConflict`) via `nickel export dag.yaml --apply-contract ledger/contracts/dag_apply.ncl`;
- this protocol;
- the gate scripts under `ledger/gate/` and `gates/` (the evaluators the steps
  name).

---

## State

The orchestrator's entire state is reconstructable from git + the sketch
checkpoint (rules.md §5). It tracks, per node:

```
STATUS  : PENDING | DISPATCHED | LANDED | ACCEPTED | REWORK | INVALIDATED
worktree: path under .scratch/worktrees/<node-id>   (once dispatched)
branch  : node/<node-id>                             (the worker's branch)
```

and globally:

```
shared_branch : the campaign integration branch (e.g. campaign/<topic>)
tip           : the commit the current layer's worktrees branch from
layers        : the Kahn layering, derived (below), never hand-authored
```

---

## Derived schedule (no improvisation)

The execution order is computed from the DAG, not chosen. Export the layering:

```bash
nix run nixpkgs#nickel -- export ledger/derive/layers.ncl
```

This emits `{ layer_count, layers }` where `layers[k]` is the set of node ids
whose dependencies are all settled in layers `< k`. Nodes within a layer have no
dependency path between them, so they are *candidates* for parallel dispatch;
the conflict gate (below) decides which actually run concurrently. The
derivation imports the validated DAG, so it only ever computes over a graph that
already passed `Dag` + `DagNoConflict`. Re-running it on the same DAG reproduces
the same layering — the schedule is a pure function of the topology.

---

## The driver loop

```
DRIVE(dag):
  assert  nickel export dag --apply-contract ledger/contracts/dag_apply.ncl  exits 0  # structural gate
  layers := export ledger/derive/layers.ncl
  shared_branch := create from current HEAD
  tip := HEAD
  for k in 0 .. layer_count - 1:
      RUN_LAYER(layers[k], dag, tip, shared_branch)
      LAYER_BOUNDARY(layers[k], dag, tip, shared_branch)   # cumulative-diff gate
      tip := shared_branch HEAD          # advance the tip per layer
  CLOSE(dag, shared_branch)
```

Each layer branches from the **previous layer's merged tip**, so a node always
sees its dependencies' landed work. This is why premise-freshness (below) is
checked per boundary and not once up front: each merge mutates the world the
next layer's premises were written against. `LAYER_BOUNDARY` runs once per layer
edge, *after* every node in the layer has merged and *before* the tip advances —
the cumulative-diff coherence gate (below) that no single per-node reconcile can
see.

### RUN_LAYER

```
RUN_LAYER(layer, dag, tip, shared_branch):
  # 1. PARTITION the layer into a conflict-free parallel set + a serial rest.
  parallel, serial := PARTITION(layer, dag)

  # 2. DISPATCH the parallel set concurrently; each worker in its own worktree.
  for node in parallel:           DISPATCH(node, tip)
  for node in parallel:           AWAIT(node)            # workers run; collect

  # 3. RECONCILE each landed node IN A FIXED ORDER (layer order), then merge.
  for node in sort(parallel):     RECONCILE_AND_MERGE(node, dag, shared_branch)

  # 4. The serial rest runs one at a time, each branching from the now-advanced
  #    shared branch, reconciled and merged before the next starts.
  for node in serial:
      DISPATCH(node, shared_branch HEAD)
      AWAIT(node)
      RECONCILE_AND_MERGE(node, dag, shared_branch)
```

`sort` is the node-id order: reconciling in a fixed order makes the run
replayable. `PARTITION` is decided by the conflict gate, not by guesswork:

```
PARTITION(layer, dag):
  serial   := { n in layer | n has serialize=true }   # declared serial
  parallel := layer \ serial
  # The DAG already guarantees the parallel set is conflict-free: DagNoConflict
  # rejected the artifact unless every unordered pair has disjoint surfaces or a
  # serialize marker. So this partition is a read of the validated DAG, not a
  # fresh conflict computation.
  return parallel, serial
```

### DISPATCH

```
DISPATCH(node, base):
  git worktree add .scratch/worktrees/<node-id> -b node/<node-id> <base>
  node.worktree := that path
  hand the worker ONLY its IBC (prompts/<node-id>-*.md) and its discipline
  node.STATUS := DISPATCHED
```

The worktree topology is a *physical proof* of the DAG's declared independence:
two conflict-free nodes occupy disjoint worktrees branched from the same base, so
their diffs cannot collide at the file level. A worker commits in its worktree
under its discipline's commit gate (rules.md §3) and never pushes.

A worker that trips a reserved predicate or rejects its boundary **freezes and
returns its report** — that is the IBC working as designed, not a failure. Two
freeze causes have deterministic resolutions below: a surface-exceed (resolved
by the surface-exceed protocol) and a refuted premise (resolved by realignment).
Any other reserved halt is a **[HUMAN SEAM]**.

---

## RECONCILE_AND_MERGE — the per-node boundary

This is the core loop. It runs for every landed node, in order, **before** the
node is merged and **before** the next node's premises are trusted. It is where
cross-node drift dies at the boundary instead of accumulating to CLOSE.

```
RECONCILE_AND_MERGE(node, dag, shared_branch):
  node.STATUS := LANDED

  # ── (1) JUDGE THE CHANGESET — worker claims are not evidence ───────────────
  re-run the evaluators the node's IBC names in its acceptance criteria (S4),
  against the node's worktree. The worker's self-report is ignored; the
  evaluator's exit code is the verdict.
      any evaluator non-zero        -> verdict := REWORK   (go to VERDICT)

  # ── (2) SURFACE HONESTY — derive the actual touched set, reconcile ─────────
  touched := git -C <worktree> diff --name-only <base>..HEAD
  ledger/gate/authorized.py --dag <exported> --reconcile-node <node-id> \
      $(printf -- '--path %s ' $touched)
      exit 0   -> the node stayed within its declared surface
      exit 1   -> undeclared touches: run the SURFACE-EXCEED PROTOCOL on each
                  before proceeding (it either widens the surface or routes to
                  serialize/REWORK). Conflict-detection stays honest because the
                  declared surface is reconciled against reality here.

  # ── (3) BIDIRECTIONAL COHERENCE-IMPACT — break already-landed OR pending? ──
  ledger/gate/coherence_impact.sh <repo-root> [--removed <workflow> ...]
      exit 1   -> INCOHERENT: a machine-check failed (e.g. this landing left a
                  live reference to a workflow a sibling removed). verdict :=
                  REWORK. Breakage caught at THIS boundary, not at CLOSE.
      exit 0   -> machine surface coherent; the DISPATCH lines name the concerns
                  with no evaluator (semantic coherence), routed to decorrelated
                  review (the adversarial path). The orchestrator records each
                  dispatch and its converged verdict before ACCEPT.

  # ── (4) PREMISE-FRESHNESS — re-verify EVERY pending node against new HEAD ──
  for p in pending nodes:
      ledger/gate/premise_fresh.sh <p-id> <p's tripwire spec>
          exit 1 -> p.STATUS := INVALIDATED; realign p's IBC before it
                    dispatches (REALIGN, below). A stale premise never reaches
                    a worker.
          exit 0 -> p stays FRESH.

  # ── (5) VERDICT ───────────────────────────────────────────────────────────
  VERDICT:
    ACCEPT  (all of 1–4 clean, reviews converged-pass):
        merge node/<node-id> into shared_branch (any strategy: standard, octopus, or fast-forward)
        node.STATUS := ACCEPTED; mark its mitigated findings
    REWORK  (an evaluator, surface, or coherence check failed):
        emit a corrective delta IBC naming the failing evaluator's output;
        re-dispatch the node from the current shared tip; node.STATUS := PENDING
    ESCALATE (the fault is the plan's, not the worker's — e.g. the DAG
        under-modeled a dependency):  return to PLAN/ORCHESTRATE and realign the
        DAG itself. [HUMAN SEAM] only if the realignment needs a decision rights
        call beyond the IBC's declared sovereignty gates.

  # ── (6) CHECKPOINT — reconstruct, don't recall ─────────────────────────────
  append a RECONCILE_LOG round (judged verdicts, freshness results,
  realignments) and write the sketch checkpoint; commit it in the sketches
  subrepo. A crash after this point resumes from sketch + git alone.
```

The two checks the campaign previously ran implicitly are now steps (3) and (4),
each with a named evaluator and an exit-code decision rule. Step (4)'s
"re-verify EVERY pending node" is the explicit per-boundary freshness pass; in
the cohesion campaign this was only implicit (branch-from-updated-tip plus
fault-driven realignment), which is why the F-series coherence findings surfaced
at CLOSE rather than at a boundary.

### REALIGN (an invalidated or reworked node)

```
REALIGN(node, reason):
  rewrite the node's IBC premises/surface to the world current HEAD describes
  if the realignment changes the DAG topology or surfaces:
      re-export dag --apply-contract ledger/contracts/dag_apply.ncl   # must pass Dag ∘ DagNoConflict again
      re-export ledger/derive/layers.ncl    # the schedule may have changed
  node.STATUS := PENDING
  log the realignment and its reason in the RECONCILE_LOG
```

Realignment edits are deterministic *mechanics* (rewrite premises to match HEAD,
re-export, re-derive). The *content* of a premise rewrite can require judgment;
when it does and the judgment is not covered by a declared sovereignty gate,
that is a **[HUMAN SEAM]**.

---

## LAYER_BOUNDARY — the per-layer cumulative-diff coherence gate

`RECONCILE_AND_MERGE` step (3) judges *one node's* landing. But file-surface
disjointness — what `DagNoConflict` proves and what the per-node surface-honesty
check confirms — is **not** semantic independence: a **cut or rename** in one
node can orphan a reference living in a *surviving* file that no node in the
layer declares, invisible to every per-node gate. (The cohesion campaign learned
this: removing a workflow left dangling references that surfaced only at CLOSE.)
So once every node in a layer has merged, before the tip advances, the boundary
runs a coherence gate over the **layer's cumulative diff** for the campaign's
whole cut-set:

```
LAYER_BOUNDARY(layer, dag, tip, shared_branch):
  # run only at a QUIESCENT edge — every node in `layer` merged, no worktree
  # mid-write — because index-sensitive evaluators give false failures otherwise.
  cut_set := workflows this layer removed or renamed (from the merged diff)

  ledger/gate/coherence_impact.sh <repo-root> $(printf -- '--removed %s ' $cut_set)
      # coherence_impact internally runs the contract export, the orphan gate
      # (check_orphans over the cut_set), and the markdown-link gate over the
      # cumulative surface — one call, three machine-checks.
      exit 0  -> the layer is semantically coherent; advance the tip.
      exit 1  -> INCOHERENT: a cut/rename orphaned a cross-node reference. This
                 fault is NOT localizable to a single node (the broken ref and
                 the cut that broke it live in different nodes' surfaces), so it
                 does NOT route to single-node REWORK. It routes to
                 ESCALATE -> PLAN: the architect seat realigns the plan/DAG for
                 the cross-node coupling (re-export, re-derive, re-dispatch the
                 affected nodes). [HUMAN SEAM] if the realignment needs a
                 decision-rights call beyond the IBC's declared sovereignty gates.
```

This is a **boundary** gate (cumulative diff, whole cut-set), distinct from the
per-node check: it catches cross-node orphaning a single node's reconcile cannot
see, and it catches it *here* rather than at CLOSE. Because the fault is a
plan-level cross-node coupling, the architect seat's corrective (ESCALATE → PLAN)
is the right resolution — exactly how a campaign handles a coupling its node
decomposition under-modeled.

---

## The surface-exceed protocol

A worker HALTs before touching a file outside its declared `file_surface`
(fail-closed authorization — the halt is correct, not a bug). The orchestrator
resolves it deterministically:

```
SURFACE_EXCEED(node, requested_path, dag):
  concurrent := surfaces of every node UNORDERED with `node` in the current
                layer (its CONCURRENT set, read from the validated DAG)
  ledger/gate/authorized.py --collision-check \
      --path <requested_path> \
      --against-surfaces "<concurrent surfaces, comma-joined>"
      exit 0  (WIDEN):     no concurrent node owns the path. Authorize-and-widen:
                           add <requested_path> to node's file_surface, re-export
                           the DAG (must still pass Dag ∘ DagNoConflict), resume
                           the worker.
      exit 3  (SERIALIZE):  a concurrent node's surface contains the path. Do NOT
                           widen — that would create an undeclared concurrent
                           conflict. Instead mark `node` serialize=true (or add a
                           dependency edge to the owning node), re-export, and
                           re-schedule it into the serial rest.
```

The collision-check uses the same path-containment overlap as the DAG contract
(`docs/` contains `docs/x.md`), so the gate and the contract never disagree. The
exit code *is* the routing decision; the orchestrator does not interpret it.

---

## CLOSE

> [!IMPORTANT]
> **Dual-CLOSE Invariant.** CLOSE terminates only when **both** conditions hold:
>
> **(a) Deterministic path** — the full gate suite exits green, proving the
> machinery **executes**. A green suite is necessary but not sufficient: it
> proves execution, not wiring or coverage.
>
> **(b) Adversarial path** — a decorrelated, context-free sufficiency review
> finds the machinery **wired in and sufficient**, proving that what the gates
> claim to check is actually checked. Context-free reviewers (ideally a model
> switch, per the [dialectic principle](../ambient.md)) ask: "what does no gate
> check, what is defined-but-unwired, what claim is hollow?" Their findings
> route to follow-up nodes or recorded tech-debt before final acceptance.
>
> This campaign's own green CLOSE missed real holes — a new DAG format not
> wired into any gate, a trusted cache, a rename blind spot — that a
> decorrelated review then found. The gate suite was green; the machinery was
> not sufficient. The dual closes the gap.
>
> The review verdict is adversarial-path (no machine can decide "is this gate
> sufficient?"). The retrospective's "## Sufficiency Review" section is the
> durable record; `ledger/gate/recorder_close_check.sh` enforces a structural
> floor — the heading must be present **and** carry at least one non-blank,
> non-heading line beneath it. A hollow heading (present but empty) fails the
> check. Content quality — genuine reviewers, real convergence, honest findings
> — is the adversarial reviewer's responsibility, not the gate's.

```
CLOSE(dag, shared_branch):
  # ── (a) Deterministic path: the full gate suite must exit green ──────────────
  assert  every finding is MITIGATED or human-accepted ACCEPTED_RISK
  assert  every node is ACCEPTED
  run the full deterministic surface over shared_branch (gate suites,
      nickel exports, adherence audit, linters — all 0)

  # ── (b) Adversarial path: sufficiency review ─────────────────────────────────
  dispatch decorrelated sufficiency review over the full gate surface:
      "what does no gate check, what is defined-but-unwired,
       what claim is hollow?"                                   # adversarial-path
  route findings to follow-up nodes or tech-debt records before acceptance

  # ── Integration-drift sweep (a separate adversarial-path check) ──────────────
  run ONE final decorrelated MBSS sweep over the cumulative diff for
      cross-node integration drift no single boundary could see # adversarial-path

  # ── Retrospective and close record ───────────────────────────────────────────
  emit the retrospective to .ledger/log/ (`log: close <topic> retrospective`);
      the retrospective MUST include a "## Sufficiency Review" section
      (reviewers, convergence verdict, and any findings routed to follow-up
       nodes or tech-debt records — the durable trace of path (b);
       content quality is the orchestrator's responsibility, not the gate's)
  ledger/gate/recorder_close_check.sh <topic>           # rc≠0 → HALT
      # structural floor: verifies BOTH the close entry AND that its
      # "## Sufficiency Review" section is present and non-empty (at least
      # one substantive line beneath the heading). A hollow heading fails.
      # Genuine reviewers and honest convergence are enforced by the
      # adversarial path, not by this gate.

  produce the campaign report from REVIEW.md -> outcomes
  rm -f $root/.ledger/active-dag
  [HUMAN SEAM] HALT for human final acceptance and any git push (agents never
      push; remotes belong to the human — rules.md §3).
```

The per-boundary coherence step (RECONCILE step 3) shrinks what CLOSE can find:
if every boundary caught its own breakage, CLOSE's final sweep is a confirmation,
not a rescue. The Dual-CLOSE Invariant closes the complementary gap: if the gate
machinery itself is under-wired or covers less than it claims, a green sweep
confirms nothing. Both paths must close.

---

## The automatability boundary

Every step above is deterministic-or-dispatched except the points marked
**[HUMAN SEAM]**. Collected, those are the irreducible human role — the residual
ambiguity the formalization cannot remove:

| Seam | Where | Why it is irreducible |
| :--- | :--- | :--- |
| Final acceptance + push | CLOSE | Remotes belong to the human (rules.md §3); a release is a sovereignty decision. |
| Non-resolvable reserved halt | DISPATCH | A reserved predicate beyond surface-exceed / refuted-premise is, by definition of "reserved," a head escalation. |
| Decision-rights realignment | REWORK/ESCALATE, REALIGN | When realigning needs a call outside the IBC's declared sovereignty gates. |
| Non-converging adversarial review | RECONCILE step 3 | When decorrelated reviewers do not converge, the dual escalates to human (rules.md §1). |
| Non-converging sufficiency review | CLOSE | When the sufficiency reviewers do not converge on a SUFFICIENT verdict, CLOSE cannot complete without the head's resolution of the open questions. |

In an `AUTONOMOUS`-mode campaign these seams resolve by policy or escalate; in
`INTERACTIVE` mode they surface to the person. Everything else — schedule
derivation, dispatch, the four reconcile checks, the surface-exceed routing, the
merge, the checkpoint — runs from the DAG and this protocol with no improvisation.
