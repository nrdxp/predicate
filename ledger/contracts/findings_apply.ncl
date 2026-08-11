# Apply-contract for findings ledgers authored as pure-data YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <findings>.yaml --apply-contract ledger/contracts/findings_apply.ncl
#
# findings.ncl is the law and stays UNCHANGED. Its `Findings` contract carries
# the intrinsic gate: a finding at a RESOLVED status whose evaluator is absent
# or unrun makes `nickel export` exit non-zero.
#
# The YAML→tag lift this shim used to perform is gone: the reformed law's
# enums are value-restricted tag-or-string and its gate compares through the
# core's `matches`, so a raw YAML string enforces identically to a tag.
(import "findings.ncl").Findings
