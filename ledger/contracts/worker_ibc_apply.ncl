# Apply-contract for worker IBCs authored as pure-data YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <ibc>.yaml --apply-contract ledger/contracts/worker_ibc_apply.ncl
#
# worker_ibc.ncl carries the law and stays unchanged. Composes Worker (shape:
# premises as closed claim entries, unknowns as routable questions, normative
# sections as provenance-carrying Directives) with WorkerIBC (the sufficiency
# gate). All enums are value-restricted tag-or-string, so no YAML→tag lifting
# is needed.
let c = import "worker_ibc.ncl" in
std.contract.all_of [c.Worker, c.WorkerIBC]
