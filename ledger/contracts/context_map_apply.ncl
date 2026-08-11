# Apply-contract for context maps authored as pure-data YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <context_map>.yaml --apply-contract ledger/contracts/context_map_apply.ncl
#
# context_map.ncl is the law and stays UNCHANGED. Its `ContextMap` contract
# dispatches each item by `kind` (directive rows vs question-entry unknowns)
# and enforces the intrinsic gate per item.
#
# The YAML→tag lift this shim used to perform is gone: the reformed law's
# `kind` is value-restricted tag-or-string (ruling D-6), so a plain YAML
# string validates — and is value-restricted — without lifting.
(import "context_map.ncl").ContextMap
