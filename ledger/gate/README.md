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

`nickel` need not be on `PATH`. The runner resolves to a direct `nickel`
or to `nix run nixpkgs#nickel --`, so the one command is identical across
a human shell and a headless CI. If neither is reachable the gate halts
non-zero — a gate that cannot run is not a gate that passes.

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

## Files

| File | Holds |
| :--- | :--- |
| `ledger-validate.sh` | The gate: portable runner + structure + authority. |
| `authorized.py` | The authorization predicate over an exported DAG JSON. |
| `demo_unauthorized.sh` | Reproducible demo: an unauthorized staged change exits non-zero (baseline ΔE₀ ≠ 0); an authorized path passes. |

## Demonstration

```bash
ledger/gate/demo_unauthorized.sh   # exits 0 iff the gate behaved as specified
```

The demo stages a file under a path no node covers, asserts the gate
denies it, cleans up, then confirms an authorized path passes — the
baseline ΔE₀ ≠ 0 the gate exists to produce.
