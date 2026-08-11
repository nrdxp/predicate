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

## The seven scopes

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

### `project_local`

Fires on **every** `git commit`, regardless of whether a campaign or walk
is active. Applies to **both humans and agents**.

This is the **project-local tier** in `hooks/pre-commit` — check 6:

- **Project-local gates** (`hook/pre-commit:project-local`) — the consuming
  project declares its own idiosyncratic checks in `.ledger/gates/`. The runner
  discovers every executable file in that directory, runs them in sorted name
  order with the project root as `$1`, and exits non-zero iff any fail.
  Implemented by `ledger/gate/project-gates.sh`.

**Opt-in, zero-predicate-idiosyncrasy.** A project with no `.ledger/gates/`
directory incurs zero overhead — the runner's own no-op-when-absent property
IS the activation guard. Predicate's shipped machinery contains no knowledge
of any consuming project's rules; those live entirely in the gate scripts
the project deposits in `.ledger/gates/`.

**Gate script interface.** Each file in `.ledger/gates/` must be executable.
When the runner invokes it:

- `$1` = absolute path to the gated project root
- Exit `0` = pass; non-`0` = fail
- Diagnostics go to stderr, naming the failing condition

Authors control execution order by naming files with a numeric prefix
(`01-lint.sh`, `02-validate.sh`, …) — no manifest file is required.
Non-executable files in the same directory (e.g. a `README.md`) are silently
skipped.

**Example — a simple project-local gate:**

```bash
# .ledger/gates/01-no-fixme.sh — blocks commits that introduce FIXME markers
#!/usr/bin/env bash
root="$1"
if git -C "$root" diff --cached -U0 | grep -q '^+.*FIXME'; then
  echo "project-gate: FIXME marker in staged diff" >&2
  exit 1
fi
exit 0
```

### `recorder`

Fires on **every commit made INSIDE a `.ledger` subrepo** — a different commit
path from every scope above, which all govern the *project* repo. `.ledger/`
is its own git repository (never part of the project repo — see
[`ledger/README.md`](../ledger/README.md)), so a commit made inside it is
invisible to `hook/pre-commit` and every one of its tiers. Applies to **both
humans and agents**.

- **Record structure** (`ledger/gate/recorder-pre-commit.sh`) — a staged
  `tech-debt/*.yaml` or `process-feedback/*.yaml` file must validate against
  its class contract (`skills/record/tech_debt_apply.ncl` /
  `skills/record/process_feedback_apply.ncl`). A staged file outside those two
  namespaces is skipped. If a record is staged and `nickel` is not on PATH,
  the gate fails (exit 2) rather than silently passing.

Installed into `<ledger>/.git/hooks/pre-commit` by
`ledger/gate/install-recorder-hook.sh`, composed from `bootstrap/install.sh
init` the same way `hooks/install-hooks.sh` composes the project's own hooks
(self-locating symlink, idempotent, never clobbers a foreign hook on
teardown). `bootstrap/install.sh deinit` reverses it symmetrically, preserving
every byte of `.ledger`'s data and history.

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
| `hook/pre-commit:project-local` | project_local | every commit; no-op when `.ledger/gates/` absent | human + agent |
| `ledger/gate/ledger-validate.sh` | predicate_artifact | commit-time (structure); orchestration (authorize/commit-gate) | human + agent |
| `ledger/gate/authorized.py` | campaign | called by ledger-validate.sh authorize | agent only |
| `ledger/gate/process-gate.sh` | walk | walk-activated, validates procedure deposits | agent only |
| `ledger/gate/project-gates.sh` | project_local | every commit; discovers + runs `.ledger/gates/` executables | human + agent |
| `ledger/gate/recorder-pre-commit.sh` | recorder | every commit inside a `.ledger` subrepo; validates staged tech-debt/process-feedback records | human + agent |
| `ledger/gate/install-recorder-hook.sh` | recorder | `bootstrap/install.sh init`; wires recorder-pre-commit.sh into `<ledger>/.git/hooks/pre-commit`, idempotently | human + agent |
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
| `ledger/gate/test_recorder_hook.sh` | orchestration | CI gate-test step; exercises recorder-pre-commit.sh + install-recorder-hook.sh init/deinit wiring | agent only |
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
