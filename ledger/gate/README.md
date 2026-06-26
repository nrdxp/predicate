# Ledger Gate — One Command, Two Checks, Two Call Sites

The gate that runs the ledger at every boundary. One command,
`ledger-validate.sh`, is invoked at **both** the commit gate
(`rules.md` §3) and at **dispatch** — so an autonomous walk meets the
identical gate a human does. It carries two checks that share one
principle: *demonstrate the condition unforgeably.*

| Check | Question | How it fails |
| :--- | :--- | :--- |
| **Structure** | Does the artifact satisfy its Nickel contract? | `nickel export` exits non-zero; the diagnostic names the broken invariant. |
| **Authority** | Is every changed path authorized? | A staged path no DAG node's `file_surface` covers fails the gate — *not in the IBC → not authorized.* |

The structure check reuses the substrate's own gate (see
[`../README.md`](../README.md)): exporting the artifact *is* the
validation, so there is no out-of-band step a headless orchestrator can
skip. The authority check is the campaign principle made mechanical: a
change is authorized only when some node in the validated DAG declared a
`file_surface` covering it. A direct `/core` task is a degenerate
one-node DAG, so the property holds universally without extra ceremony.

## Portability (AC7)

`nickel` must be on `PATH`. The runner calls `nickel` directly — there is
no `nix run nixpkgs#nickel` fallback. For local development, enter the
project shell (`nix-shell` or `nix develop` with `shell.nix`) which
provides nickel 1.14.0. CI installs nickel via `nix profile install
nixpkgs#nickel` before invoking the gate suites. If `nickel` is not
reachable the gate halts non-zero — a gate that cannot run is not a gate
that passes.

## Downstream import convention

A downstream repo that writes its own Nickel artifacts can import predicate
contracts by **logical name** — no vendoring, no absolute paths, no relative
traversal into the plugin tree.

```nickel
# downstream_dag.ncl — lives in the consuming repo, NOT in predicate
let c = import "dag.ncl" in
{ nodes = [ ... ] } | c.Dag | c.DagNoConflict
```

The gate runner resolves `"dag.ncl"` because it injects
`-I <plugin>/ledger/contracts` after the `export` subcommand at every Nickel
call site. `<plugin>` is the real directory of the installed predicate tree,
derived from `$here` (the script's own realpath) two levels up —
`<plugin>/ledger/gate/` → `<plugin>/ledger/` → `<plugin>`. This is the same
`$plugin`-relative pattern used by `coherence_impact.sh` (P21).

**Internal contracts keep relative imports.** Predicate's own fixtures import
with `import "../contracts/dag.ncl"`. Nickel resolves relative imports against
the importing file first; `-I` is only a fallback search dir. Existing
self-hosted artifacts are unaffected — additive only.

| Consumer | Import form | Resolved by |
| :--- | :--- | :--- |
| Predicate internal | `import "../contracts/dag.ncl"` | Nickel's file-relative resolution |
| Downstream repo | `import "dag.ncl"` | `-I <plugin>/ledger/contracts` injection |

## Commands

```bash
# Structure only: export-validate one artifact (exit 0 iff it conforms).
ledger/gate/ledger-validate.sh structure <artifact>.ncl

# Authority: validate the DAG, then authorize given paths (or, with none,
# the staged change set: git diff --cached).
ledger/gate/ledger-validate.sh authorize <dag>.ncl [path ...]

# Commit-gate entry (what rules.md §3 wires): structure-validate the DAG,
# then authorize the staged change against it.
ledger/gate/ledger-validate.sh commit-gate <dag>.ncl
```

Exit codes: `0` pass, `1` a check failed, `2` usage or environment error.

## Scale invariance

The gate is the same at every scale: the boundary a multi-node campaign
DAG passes and the boundary a direct `/core` task passes run the
identical command set, because a `/core` task is a degenerate one-node
DAG. `gate-set.sh` proves this *mechanically* — the gate set a `/core`
task runs is a **superset** of the gate set a node runs.

| Set | Is | Source |
| :--- | :--- | :--- |
| **node** | the universal Commit Gate, nothing more | `rules.md` §3 |
| **/core** | those same gates **plus** the Verification Protocol additions | `rules.md` §3 + §4 |

Each set is data — `gate-sets/node.txt`, `gate-sets/core.txt` — one
gate identifier per line. The `/core` set adds the §4 gates a feature
task runs (TDD baseline failure, one-shot skepticism, iteration
transparency, the refinement loop) on top of the node set, never
removing any. The proof is set inclusion:

```bash
ledger/gate/gate-set.sh check   # comm -23 node core; exit 0 iff empty
ledger/gate/gate-set.sh diff    # the gates /core adds over a node
```

`comm -23 <node> <core>` emits node gates not covered by `/core`; empty
output means `node ⊆ core`, so the `/core` set is a superset. A
non-empty line is an uncovered node gate and the check exits non-zero
naming it.

```bash
ledger/gate/demo_scale_invariant.sh   # exits 0 iff transcripts coincide
```

The demonstration runs the gates rather than asserting the property: it
builds a one-node DAG, stages one authorized change, runs the identical
commit-gate sequence under the campaign DAG and the one-node DAG, and
asserts the two gate transcripts are byte-identical — a `/core` task
passes exactly the gates a node does.

## Project-local gates

A consuming project can declare its own idiosyncratic checks in
`.ledger/gates/` — project data, not shipped predicate machinery. The runner
`project-gates.sh` is invoked as tier 6 of `hooks/pre-commit` on every
commit, discovers all executable files in that directory, runs them in
sorted name order with the project root as `$1`, and exits non-zero iff any
fail. A project with no `.ledger/gates/` directory is a clean no-op.

See [`docs/gates.md`](../../docs/gates.md) — the `project_local` scope
section — for the full interface contract and a worked example.

### Predicate's own project-local gates (templates/project-gates/)

Predicate ships its own project-local gates as tracked templates. The
**tracked source** is `templates/project-gates/`; the **runtime location**
remains `.ledger/gates/` (gitignored, per-project). `bootstrap/install.sh init`
copies every file from `templates/project-gates/` into the target project's
`.ledger/gates/` (idempotent: skip-if-exists, never clobbers a user's own
same-named gate).

This makes the guarantee durable across clones: a fresh `git clone` of
predicate followed by `bootstrap/install.sh init --project .` gets predicate's
project-local gates installed immediately, without relying on an agent session
that happened to write them previously.

Currently shipped:

| Gate | File | Enforces |
| :--- | :--- | :--- |
| Skill-contract colocation | `10-skill-contract-colocation.sh` | The five skill-owned contracts (`boundary_procedure`, `refine_procedure`, `refine_output`, `state_machine`, `tracker_freshness`) must not reappear in `ledger/contracts/`; fails on re-centralization. |

The `10-` numeric prefix places the colocation check early in sorted execution
order without preventing a project from inserting gates before it (e.g. `05-`).
Gates in `templates/project-gates/` are declared in `scopes.ncl` under the
`project_local` scope so the completeness manifest stays accurate.

## Files

| File | Holds |
| :--- | :--- |
| `ledger-validate.sh` | The gate: portable runner + structure + authority. |
| `authorized.py` | The authorization predicate over an exported DAG JSON. |
| `project-gates.sh` | Project-local gate runner: discovers `.ledger/gates/` executables and runs them in sorted order. |
| `gate-set.sh` | The scale-invariance check: proves `/core` gates ⊇ node gates by `comm -23`. |
| `gate-sets/` | The two gate sets as data — `node.txt`, `core.txt`. |
| `demo_unauthorized.sh` | Reproducible demo: an unauthorized staged change exits non-zero (baseline ΔE₀ ≠ 0); an authorized path passes. |
| `demo_scale_invariant.sh` | Reproducible demo: a `/core` task's gate transcript matches a node's, re-run not claimed. |

## Demonstration

```bash
ledger/gate/demo_unauthorized.sh   # exits 0 iff the gate behaved as specified
```

The demo stages a file under a path no node covers, asserts the gate
denies it, cleans up, then confirms an authorized path passes — the
baseline ΔE₀ ≠ 0 the gate exists to produce.
