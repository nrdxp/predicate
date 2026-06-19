# Clean example: a worker IBC rendered as a ledger record (the Nickel-substrate
# node's own boundary). Exports 0.
let c = import "../contracts/worker_ibc.ncl" in
(
  {
    id = "P3",
    tier = "worker / opus-class",
    discipline = 'core,
    depends_on = [],
    goal = "Author the Nickel contracts that make every ledger artifact machine-validating.",
    non_goals = [
      "Do not wire the gate into commit/dispatch (downstream node).",
      "Do not add grammars to prose lenses.",
      "Do not redesign the validated DAG algorithm — port it.",
    ],
    premises = [
      {
        id = "P3.1",
        statement = "Nickel is runnable via nix run nixpkgs#nickel.",
        check = "nix run nixpkgs#nickel -- --version exits 0",
        verified = "2026-06-19 — nickel 1.17.0",
      },
    ],
    delegated = [
      "Exact record/enum shapes for each ledger artifact.",
      "Where the contracts physically live (ledger/).",
    ],
    reserved = [
      "IF Nickel proves unworkable for a needed contract THEN halt and reconsider the substrate.",
    ],
    constraints = [
      {
        id = "C-P3.1",
        statement = "Each contract's clean example exports 0.",
        evaluator = "nix run nixpkgs#nickel -- export <example>.ncl exits 0",
      },
      {
        id = "C-P3.2",
        statement = "Cycle, dangling, and conflict fixtures each export non-zero.",
        evaluator = "nix run nixpkgs#nickel -- export <fixture>.ncl exits non-zero",
      },
    ],
    context_map = [
      "ledger/contracts/dag.ncl — the lifted Dag + DagNoConflict.",
      "templates/IBC.md — the S1-S7 worker-IBC shape.",
    ],
    acceptance = [
      {
        id = "AC-P3.1",
        statement = "A contract plus one clean example for each ledger artifact.",
        eval = "nickel export exits 0 on each example",
      },
      {
        id = "AC-P3.2",
        statement = "Cycle/dangling/conflict fixtures export non-zero.",
        eval = "nickel export exits non-zero on each fixture",
      },
    ],
    load_bearing = [
      "Nickel as the substrate; intrinsic acyclicity + referential integrity.",
    ],
    plastic = [
      "Exact schema shapes; the ledger/ location.",
    ],
  } | c.Worker
) | c.WorkerIBC
