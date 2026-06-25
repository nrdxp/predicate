# Orchestration driver — recorded demo run (C13-2 / AC5)

The orchestration skill ([`../SKILL.md`](../SKILL.md)) DRIVING the deterministic
procedure in [`docs/orchestration-protocol.md`](../../../docs/orchestration-protocol.md)
over a small synthetic DAG. This is the example test: the acceptance vehicle for
the "DRIVE the protocol over a live DAG" contract. Every command below was run
against the **real** gate scripts; the recorded `rc` is the gate's actual exit.

## Reproduce the schedule derivation yourself

```bash
# Validate the YAML DAG (Dag ∘ DagNoConflict — instances are YAML, contracts are Nickel):
nickel export skills/orchestration/demo/dag.yaml \
  --apply-contract ledger/contracts/dag_apply.ncl   # rc 0 (structural gate)
# Derive the Kahn layer schedule:
nickel export skills/orchestration/demo/layers.ncl  # the Kahn schedule
```

`layers.ncl` is the live `ledger/derive/layers.ncl` derivation **verbatim**, with
its DAG import bound to this demo fixture (`import "dag.yaml"`) — the input-contract
parameterization the skill documents. Only the import path differs from the
live derivation; the schedule logic is byte-identical.

## Demo DAG ([`dag.yaml`](dag.yaml)) — 2 layers, a parallel pair, a serialize edge

| Node | depends_on | file_surface | layer | role |
| :--- | :--- | :--- | :--- | :--- |
| D1 | — | `demo/base.txt` | L1 | foundation |
| D2 | D1 | `demo/a.txt` | L2 | parallel (disjoint from D3) |
| D3 | D1 | `demo/b.txt` | L2 | parallel (disjoint from D2) |
| D4 | D1 | `demo/a.txt`, `serialize=true` | L2 | serial (shares D2's surface) |

## DERIVE — schedule reproduced

```
$ nickel export skills/orchestration/demo/dag.yaml \
    --apply-contract ledger/contracts/dag_apply.ncl
  -> rc=0                                   # Dag ∘ DagNoConflict structural gate
$ nickel export skills/orchestration/demo/layers.ncl
{ "layer_count": 2, "layers": [ ["D1"], ["D2","D3","D4"] ] }
  -> rc=0
```

## RUN_LAYER L1 — [D1]

```
$ git worktree add .../D1 -b orchdemo/D1 HEAD            -> rc 0
  (worker lands demo/base.txt in its worktree)
[RECONCILE D1 (2) surface honesty]
$ python3 ledger/gate/authorized.py --dag demo/dag.json --reconcile-node D1 --path demo/base.txt
OK    demo/base.txt  <- declared surface of D1
PASS: every touched path of node D1 falls under its declared surface   -> rc 0
[MERGE] git merge --no-ff orchdemo/D1   -> shared tip advances to <L1 merge commit>
```

## RUN_LAYER L2 — PARTITION: parallel [D2,D3], serial [D4]

Parallel pair dispatched from the **advanced** L1 tip (each its own worktree — the
physical proof of independence):

```
$ git worktree add .../D2 -b orchdemo/D2 <L1-tip>       -> rc 0
$ git worktree add .../D3 -b orchdemo/D3 <L1-tip>       -> rc 0
[RECONCILE in node-id order]
$ authorized.py --dag demo/dag.json --reconcile-node D2 --path demo/a.txt   PASS  -> rc 0
$ authorized.py --dag demo/dag.json --reconcile-node D3 --path demo/b.txt   PASS  -> rc 0
[MERGE D2, then D3, --no-ff in node-id order]   -> shared tip advances
```

### SURFACE_EXCEED — the routing that proves why D4 is serial

```
[D4's surface (demo/a.txt) collides with concurrent D2's surface]
$ authorized.py --collision-check --path demo/a.txt --against-surfaces demo/a.txt
COLLIDE demo/a.txt  <- concurrent surface demo/a.txt
SERIALIZE: 1 collision(s) ...                                          -> rc 3 (SERIALIZE)

[contrast: a path no concurrent node owns]
$ authorized.py --collision-check --path demo/c.txt --against-surfaces demo/a.txt
WIDEN: requested paths are disjoint from all concurrent surfaces       -> rc 0 (WIDEN)
```

The exit code *is* the routing decision: rc 3 → keep D4 in the serial rest; rc 0
would authorize-and-widen. D4 carries `serialize=true`, so it runs serially:

```
[SERIAL: dispatch D4 from the now-advanced shared tip]
$ git worktree add .../D4 -b orchdemo/D4 <post-parallel-tip>           -> rc 0
  (worker extends demo/a.txt — serial, so no concurrent conflict)
$ authorized.py --dag demo/dag.json --reconcile-node D4 --path demo/a.txt
PASS: every touched path of node D4 falls under its declared surface   -> rc 0
[MERGE D4 --no-ff]   -> shared tip advances
```

### RECONCILE (4) PREMISE-FRESHNESS — re-verify a pending node vs HEAD

```
$ bash ledger/gate/premise_fresh.sh D-future <tripwires>
FRESH  (0==0)  test -f skills/orchestration/demo/dag.yaml
FRESH  (0==0)  grep -q orchestration skills/campaign/SKILL.md
FRESH: node D-future — every premise still holds against HEAD          -> rc 0
```

## LAYER_BOUNDARY — the cumulative-diff coherence gate (C13-8)

One command; `coherence_impact.sh` runs the contract export, the orphan gate, and
the link gate internally. GREEN (this demo cuts nothing):

```
$ bash ledger/gate/coherence_impact.sh .
PASS  contract: every ledger example still exports
PASS  links: markdown link syntax resolves
DISPATCH  semantic-coherence: no evaluator can exist -> decorrelated review
COHERENT (machine surface): all evaluators passed                      -> rc 0
```

RED — a layer cut/renamed a workflow still referenced by a surviving file (the
campaign's own lived lesson; `campaign` here stands in for a cut workflow that
still has live cross-node references):

```
$ bash ledger/gate/coherence_impact.sh . --removed campaign
PASS  contract: every ledger example still exports
FAIL  orphans: a surviving file references a removed workflow
PASS  links: markdown link syntax resolves
INCOHERENT: 1 machine-check(s) failed — breakage caught at the boundary -> rc 1
```

rc 1 routes **ESCALATE → PLAN** (architect realigns the plan/DAG for the
cross-node coupling), **not** single-node REWORK: the broken reference and the cut
that broke it live in *different* nodes' surfaces, so no single node owns the
fault. This is exactly how this campaign handled its own cross-node couplings.

## CLOSE (seam)

The four `[HUMAN SEAM]`s surface in `INTERACTIVE` mode; final acceptance + push is
never resolved by policy in either mode (remotes belong to the human — rules.md §3).

## Isolation note

Real `git worktree add` was used throughout (the per-node isolation primitive).
The demo's transient worktrees and `orchdemo/*` branches were removed after the
run; only the durable fixtures (`dag.yaml`, `layers.ncl`) and this transcript remain
under `skills/orchestration/demo/`. `git worktree list` showed only the main tree.
