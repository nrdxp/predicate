# Ledger — Machine-Validating Campaign Substrate

Every state artifact a campaign produces — its boundary, its DAG, its
findings, its reconciliation record — is rendered here as a
[Nickel](https://nickel-lang.org) contract. The contracts make the
artifacts' invariants **intrinsic**: a malformed artifact cannot be
exported. One command is the gate, with no out-of-band validation step a
headless orchestrator could skip:

```bash
nix run nixpkgs#nickel -- export <file>.ncl
```

Exit `0` means the artifact satisfies its contract. A non-zero exit means
it does not, and the diagnostic names the broken invariant.

## Layout

| Path | Holds |
| :--- | :--- |
| `contracts/` | The contracts. One file per artifact kind. |
| `examples/` | One clean instance per contract — each exports `0`. |
| `fixtures/` | Boundary controls. Negative instances export non-zero; two positive controls (a valid `'doc` discipline, a `serialize`-discharged conflict) export `0` — proving the contracts admit legitimate boundary cases as well as reject broken ones. |
| `derive/` | Derivations computed *from* an artifact (not hand-authored). |

## Contracts

| Contract | Enforces |
| :--- | :--- |
| `contracts/dag.ncl` | `Dag`: acyclicity, referential integrity, id-uniqueness. `DagNoConflict` (composed after `Dag`): concurrent nodes declare disjoint file surfaces or a `serialize` marker. |
| `contracts/findings.ncl` | A finding may not reach a resolved status (`mitigated`, `accepted_risk`) with an empty evaluator — closing a finding requires naming the gate that closed it. |
| `contracts/reconcile_log.ncl` | An `accept` verdict requires a non-empty evaluator — accepting landed work requires naming the gate that justified it. |
| `contracts/campaign_ibc.ncl` | An `autonomous` campaign may not launch from an empty goal. |
| `contracts/worker_ibc.ncl` | A worker IBC may not have an empty goal or an empty acceptance set. |

The findings, reconcile-log, campaign-IBC, and worker-IBC gates are all
one principle made intrinsic: a condition is only closed once the
evaluator that closes it is named.

## Composing a custom gate after a record contract

A `std.contract.custom` gate that reads merged fields must be applied
*after* the record-shape contract, not baked into the record literal —
otherwise the fields are not yet present when the gate runs:

```nickel
(value | Campaign) | CampaignIBC   # correct: gate sees the merged record
```

`DagNoConflict`, `CampaignIBC`, and `WorkerIBC` all follow this order.

## Derivations

`derive/layers.ncl` computes the parallel execution layering from the DAG
by Kahn's algorithm — never hand-authored. It imports the validated
example DAG, so it only ever runs over a graph that already passed the
contracts. Exporting it twice produces identical output, and every DAG
node appears in exactly one layer.

## Verifying the substrate

The contract files under `contracts/` hold contract *definitions*, not
data, so they are checked with `typecheck`, not `export` (exporting a
record of contract definitions tries to serialize functions and bare
type annotations, which is not meaningful). The instances under
`examples/`, `fixtures/`, and `derive/` are checked with `export`.

```bash
# contract definitions typecheck cleanly
for f in contracts/*.ncl; do nix run nixpkgs#nickel -- typecheck "$f"; done

# every clean example exports 0
for f in examples/*.ncl; do nix run nixpkgs#nickel -- export "$f" >/dev/null; done

# negative fixtures export non-zero; the two positive controls export 0
for f in fixtures/*.ncl; do
  case "$f" in
    *_doc_discipline.ncl|*_serialize.ncl)
      nix run nixpkgs#nickel -- export "$f" >/dev/null 2>&1 || echo "UNEXPECTED FAIL: $f" ;;
    *)
      nix run nixpkgs#nickel -- export "$f" >/dev/null 2>&1 && echo "UNEXPECTED PASS: $f" ;;
  esac
done
```
