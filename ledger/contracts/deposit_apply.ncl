# Apply-contract for deposit stores authored as pure-data YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <deposits>.yaml --apply-contract ledger/contracts/deposit_apply.ncl
#
# deposit.ncl carries the law and stays unchanged. Every deposit consumer
# aggregates ({ deposits = [...] }), so this shim applies DepositStore alone —
# per-element Evidence shape, the two species predicates, id uniqueness, and
# referential integrity all fire through the store's eager folds. All enums are
# value-restricted tag-or-string, so no YAML→tag lifting is needed.
(import "deposit.ncl").DepositStore
