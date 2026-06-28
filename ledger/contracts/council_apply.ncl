# Apply-contract for council fixtures authored as pure-data YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <fixture>.yaml --apply-contract ledger/contracts/council_apply.ncl
#
# council.ncl carries TWO contracts and stays UNCHANGED (it is the law):
#   Constitution            — the static per-project law (seats + delegation).
#   DecisionLedger(const)    — a CONSTRUCTOR parameterized by the constitution.
# A single apply-file serves both because `file_surface` names exactly one. It
# SHAPE-DISPATCHES: a value carrying `seats` is a constitution -> Constitution;
# otherwise it is a decisions ledger -> DecisionLedger threaded with the canonical
# constitution.yaml (a constructor needs its argument supplied here, since
# --apply-contract has no parameter mechanism).
#
# Imports resolve relative to THIS file's location: council.ncl sits beside it and
# constitution.yaml is one dir over under fixtures/council/.
#
# YAML→tag adapter: council.ncl's Seat.standing and DelegationRule.required_assent
# are BARE enum contracts ([| 'standing, 'guest |] etc.), which reject the plain
# strings a pure-data YAML instance necessarily carries. council.ncl is the law and
# may not change, so this adapter lifts those known strings to the tags the
# contracts expect before the law runs. Every fixture value is a valid tag, so the
# lift is lossless and no invariant is weakened — only the YAML-string / Nickel-enum
# representational gap is bridged. (Decisions carry no enum fields, so only the
# constitution needs lifting.)
let c = import "council.ncl" in
let raw_constitution = import "../fixtures/council/constitution.yaml" in

let lift_standing = match { "guest" => 'guest, "standing" => 'standing, x => x } in
let lift_assent = match {
  "single" => 'single,
  "subset" => 'subset,
  "full" => 'full,
  "human" => 'human,
  x => x,
} in
let coerce_constitution = fun con =>
  con
  & {
    seats | force =
      std.array.map (fun s => s & { standing | force = lift_standing s.standing }) con.seats,
    delegation | force =
      std.array.map (fun r => r & { required_assent | force = lift_assent r.required_assent }) con.delegation,
  }
in
let constitution = coerce_constitution raw_constitution in

std.contract.custom (fun label value =>
  if std.record.has_field "seats" value then
    std.contract.check c.Constitution label (coerce_constitution value)
  else
    std.contract.check (c.DecisionLedger constitution) label value
)
