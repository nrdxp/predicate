# Apply-contract for the entries_query views computed over a validated
# typed-claim corpus export.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <export>.yaml --apply-contract ledger/contracts/entries_query_apply.ncl
#
# entries_query.ncl is the law and stays the single source of the view
# computation (is_open, the derivation-graph walks, the view builders); this
# file only re-exports its `Views` field as the bare contract
# --apply-contract requires, mirroring entry.ncl / entry_apply.ncl's split.
#
# Imports resolve relative to THIS file's location, so entries_query.ncl and
# its transitive imports (entry.ncl, entry_apply.ncl, tag_registry.ncl) are
# found without any -I flag needed.
(import "entries_query.ncl").Views
