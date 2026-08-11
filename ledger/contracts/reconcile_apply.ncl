# Apply-contract for reconcile logs authored as pure-data YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <reconcile_log>.yaml --apply-contract ledger/contracts/reconcile_apply.ncl
#
# reconcile_log.ncl is the law and stays UNCHANGED. Its `ReconcileLog`
# contract carries the intrinsic gate: an 'accept judgment with an empty
# `evaluator` makes `nickel export` exit non-zero — accepting landed work
# requires naming the gate that justified it.
#
# The YAML→tag lift this shim used to perform is gone: the reformed law's
# enums are value-restricted tag-or-string and its gate compares through the
# core's `matches`, so a raw YAML string enforces identically to a tag.
(import "reconcile_log.ncl").ReconcileLog
