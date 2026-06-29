# Apply-contract for context maps authored as pure-data YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <context_map>.yaml --apply-contract ledger/contracts/context_map_apply.ncl
#
# context_map.ncl is the law and stays UNCHANGED. Its top-level `ContextMap`
# contract enforces the intrinsic gate per item: an item that omits or empties
# its `grounding`, `last_validated`, or `signpost` makes `nickel export` exit
# non-zero — the silent omission this carrier exists to kill.
#
# YAML→tag adapter: Item.kind is a BARE enum contract
# ([| 'requirement, 'invariant, 'constraint, 'unknown |]), which rejects the
# plain string a pure-data YAML instance carries. `ContextMap` applies `Item`
# per element under deep_seq, so without lifting even a VALID instance fails when
# `kind` arrives as a string. This adapter lifts those known strings to the tags
# the law expects BEFORE the law runs — lossless, since every valid value is a
# valid tag, and no invariant is weakened.
let c = import "context_map.ncl" in

let lift_kind = match {
  "requirement" => 'requirement,
  "invariant" => 'invariant,
  "constraint" => 'constraint,
  "unknown" => 'unknown,
  x => x,
} in
let coerce = fun value =>
  value
  & {
    items | force =
      std.array.map (fun it => it & { kind | force = lift_kind it.kind }) value.items,
  }
in

std.contract.custom (fun label value =>
  std.contract.check c.ContextMap label (coerce value)
)
