# Apply-contract for ledger entries authored as pure-data YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <entry>.yaml  --apply-contract ledger/contracts/entry_apply.ncl
#   nickel export <corpus>.yaml --apply-contract ledger/contracts/entry_apply.ncl
#
# entry.ncl carries the law and stays unchanged. A single apply-file serves
# both granularities because the declared surface names exactly one; it
# SHAPE-DISPATCHES (the council_apply.ncl idiom): a value carrying `entries`
# is an aggregate corpus -> EntryStore; otherwise it is a single entry ->
# Entry composed with the eleven lifted predicates. The lift is what makes
# each red name its own predicate: a bare boolean is not a contract in nickel
# 1.14 and from_predicate fails anonymously, so the composition here is
# std.contract.all_of over the LIFTED eleven (ruling D-9), shape first so a
# malformed entry fails on its field contract before any predicate reads it.
#
# Imports resolve relative to THIS file's location: entry.ncl sits beside it.
let e = import "entry.ncl" in
std.contract.custom (fun label value =>
  if std.is_record value && std.record.has_field "entries" value then
    std.contract.check e.EntryStore label value
  else
    std.contract.check (std.contract.all_of ([e.Entry] @ e.lifted)) label value
)
