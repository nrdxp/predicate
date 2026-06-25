# Gate Scopes

Every enforcement gate in predicate belongs to exactly one *scope*. The scope
determines **who triggers the gate** (human, agent, or CI) and **when it fires**
(on every commit, only when a campaign or walk is active, or only on the CI
orchestration path).

The machine-legible source of truth is
[`ledger/gate/scopes.ncl`](../ledger/gate/scopes.ncl).
[`ledger/gate/check_scopes.sh`](../ledger/gate/check_scopes.sh) enumerates the
actual gate surface and exits non-zero if any gate is absent from the manifest —
a new gate with no declared scope breaks the build (fails on omission).

---

## The five scopes

### `universal`

Fires on **every** `git commit`, regardless of whether a campaign or walk is
active. Applies to **both humans and agents**.

These are the commit-message gates that live in `hooks/commit-msg`:

- **Conventional Commits form** (`hook/commit-msg:hygiene`) — header length
  (≤50 chars), type prefix, blank-line separation, body line wrap (≤72 chars),
  merge-commit exemption. Implemented by
  `skills/commit-hygiene/scripts/check_commit_msg.py`.
- **Self-containment** (`hook/commit-msg:selfcontained`) — the message must be
  reconstructable from the repo alone; internal campaign node IDs (`P14`),
  layer tags (`L2`), or AC/C identifiers are rejected. Implemented by
  `gates/check_selfcontained.sh`.

### `predicate_artifact`

Fires on every commit that **stages a `*.ncl` or `*.md` file** (or any
authoritative surface file). Applies to **both humans and agents**. These are
the structural checks in `hooks/pre-commit` — they ask only "does this artifact
satisfy its own contract?", with no campaign required to be meaningful.

- **Orphan check** (`hook/pre-commit:orphans`) — no staged authoritative file
  may reference a removed/demoted workflow as if it were live (scoped to the
  staged set). Implemented by `gates/check_orphans.sh`.
- **Doc-link validation** (`hook/pre-commit:doc-links`) — staged `*.md` files
  must have valid local links and heading anchors. Implemented by
  `skills/doc-audit/scripts/check_docs.py`.
- **Ledger structure** (`hook/pre-commit:ledger-structure`) — staged `*.ncl`
  files must export (satisfy their Nickel contract). Implemented by
  `ledger/gate/ledger-validate.sh structure`.

The scripts these tiers invoke — `gates/check_orphans.sh`,
`gates/check_selfcontained.sh`, `ledger/gate/ledger-validate.sh`,
`skills/commit-hygiene/scripts/check_commit_msg.py`,
`skills/doc-audit/scripts/check_docs.py` — share this scope.

### `campaign`

Fires **iff `.ledger/active-dag` is present** (written by the orchestration
driver when a campaign is in flight, absent otherwise). Applies to **agents
only** — humans do not write the active-DAG pointer.

This is the **authority overlay** in `hooks/pre-commit`:

- **Authority check** (`hook/pre-commit:authority`) — every staged path must
  fall under some campaign DAG node's `file_surface` ("not in the IBC → not
  authorized"). Implemented by `ledger/gate/ledger-validate.sh authorize`,
  which delegates to `ledger/gate/authorized.py`.

The pointer resolves through the *common git dir*, so a worker committing from
a linked worktree still encounters the authority gate (the pointer lives in the
main tree, not the worktree).

### `walk`

Fires **iff `.ledger/active-walk` is present** (written by an agent walk at
startup via `process-gate.sh register`, removed by its teardown trap on exit).
Applies to **agents only**.

This is the **process overlay** in `hooks/pre-commit`:

- **Process check** (`hook/pre-commit:process`) — when the declared
  deposit-path is staged, it is validated against the class contract
  (`boundary` or `refine`) via `ledger/gate/process-gate.sh validate`.
  Non-deposit `*.ncl` files (contracts, DAGs, fixtures) are never
  process-validated. A human commit — which never writes the pointer — meets
  checks 1–4 only.

### `orchestration`

**Not on the commit path.** These scripts are run by the orchestration driver
or CI. Applies to **agents only** (or CI automation).

Orchestration gates include:

- Test harnesses that exercise the commit-time gates: `test_gates.sh`,
  `test_reconcile.sh`, `test_surface_protocol.sh`, `test_adherence.sh`,
  `test_contract_typecheck.sh`, `test_fixture_sweep.sh`.
- Demonstrations (smoke tests): `demo_scale_invariant.sh`,
  `demo_unauthorized.sh`.
- Completeness checker: `check_scopes.sh`.
- Scale-invariance proof: `gate-set.sh`.
- Campaign-process gates: `adherence_audit.sh` (accidental-flat-commit / drift
  detector at RECONCILE and CLOSE — catches well-intentioned agents that forgot
  worktree isolation; not hardened against agents that can mint node/* refs),
  `coherence_impact.sh` (bidirectional coherence at each node landing),
  `premise_fresh.sh` (S1 tripwire freshness before dispatch),
  `recorder_close_check.sh` (CLOSE retrospective recorded in flight log).
- Tracker-freshness gate: `tracker_fresh.sh` / `tracker_fresh.py` (context-map
  `last_validated` timestamps against HEAD commit date).
- Authorization sub-tool: `authorized.py` (called by `ledger-validate.sh`).

---

## Gate-to-scope table

The table below is derived from
[`ledger/gate/scopes.ncl`](../ledger/gate/scopes.ncl), which is the authoritative
source. If the table and the manifest ever disagree, the manifest wins.

| Gate | Scope | Fires when | Applies to |
| :--- | :--- | :--- | :--- |
| `hook/commit-msg:hygiene` | universal | every git commit | human + agent |
| `hook/commit-msg:selfcontained` | universal | every git commit | human + agent |
| `hook/pre-commit:orphans` | predicate_artifact | staged authoritative files | human + agent |
| `hook/pre-commit:doc-links` | predicate_artifact | staged `*.md` files | human + agent |
| `hook/pre-commit:ledger-structure` | predicate_artifact | staged `*.ncl` files | human + agent |
| `hook/pre-commit:authority` | campaign | iff `.ledger/active-dag` present | agent only |
| `hook/pre-commit:process` | walk | iff `.ledger/active-walk` present + deposit staged | agent only |
| `ledger/gate/ledger-validate.sh` | predicate_artifact | commit-time (structure); orchestration (authorize/commit-gate) | human + agent |
| `ledger/gate/authorized.py` | campaign | called by ledger-validate.sh authorize | agent only |
| `ledger/gate/process-gate.sh` | walk | walk-activated, validates procedure deposits | agent only |
| `ledger/gate/check_scopes.sh` | orchestration | CI gate-scope step; fails on omission | agent only |
| `ledger/gate/gate-set.sh` | orchestration | CI; scale-invariance proof | agent only |
| `ledger/gate/adherence_audit.sh` | orchestration | RECONCILE + CLOSE; accidental-flat-commit / drift detector | agent only |
| `ledger/gate/coherence_impact.sh` | orchestration | RECONCILE step; coherence check | agent only |
| `ledger/gate/premise_fresh.sh` | orchestration | before node dispatch; tripwire freshness | agent only |
| `ledger/gate/recorder_close_check.sh` | orchestration | campaign CLOSE; flight-log check | agent only |
| `ledger/gate/tracker_fresh.sh` | orchestration | /orient; context-map staleness check | agent only |
| `ledger/gate/tracker_fresh.py` | orchestration | called by tracker_fresh.sh | agent only |
| `ledger/gate/test_gates.sh` | orchestration | CI gate-test step | agent only |
| `ledger/gate/test_reconcile.sh` | orchestration | CI gate-test step | agent only |
| `ledger/gate/test_surface_protocol.sh` | orchestration | CI gate-test step | agent only |
| `ledger/gate/test_adherence.sh` | orchestration | CI gate-test step | agent only |
| `ledger/gate/test_contract_typecheck.sh` | orchestration | CI contract-typecheck step | agent only |
| `ledger/gate/test_fixture_sweep.sh` | orchestration | CI fixture-polarity-sweep step | agent only |
| `ledger/gate/demo_scale_invariant.sh` | orchestration | CI smoke + manual | agent only |
| `ledger/gate/demo_unauthorized.sh` | orchestration | CI smoke + manual | agent only |
| `gates/check_orphans.sh` | predicate_artifact | commit-time via orphan tier; standalone | human + agent |
| `gates/check_selfcontained.sh` | universal | commit-time via selfcontained tier | human + agent |
| `skills/commit-hygiene/scripts/check_commit_msg.py` | universal | commit-time via hygiene tier; CI | human + agent |
| `skills/doc-audit/scripts/check_docs.py` | predicate_artifact | commit-time via doc-links tier; CI | human + agent |

---

## Machine source of truth

[`ledger/gate/scopes.ncl`](../ledger/gate/scopes.ncl) is a Nickel manifest
validated by the structural gate on every commit that stages it. Its inline
`Scope` enum contract ensures an invalid scope (a typo or an out-of-vocabulary
value) fails `nickel export` immediately.

[`ledger/gate/check_scopes.sh`](../ledger/gate/check_scopes.sh) enforces
**completeness**: it enumerates `ledger/gate/*.sh`, `ledger/gate/*.py`,
`gates/*.sh`, the named hook tiers, and the invoked skill scripts, then exits
non-zero for any gate not declared in the manifest. A new gate added without a
scope declaration breaks CI. Run `check_scopes.sh --self-test` to verify both
the negative control (synthetic undeclared gate → rc 1) and the positive
control (complete manifest → rc 0).
