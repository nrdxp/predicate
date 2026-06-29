# Apply-contract for findings ledgers authored as pure-data YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <findings>.yaml --apply-contract ledger/contracts/findings_apply.ncl
#
# findings.ncl is the law and stays UNCHANGED. Its top-level `Findings` contract
# carries the intrinsic gate: a finding at a RESOLVED status ('mitigated or
# 'accepted_risk) with an empty `evaluator` makes `nickel export` exit non-zero.
#
# YAML→tag adapter: Finding.severity and Finding.status are BARE enum contracts
# ([| 'critical, ... |] / [| 'open, 'planned, 'mitigated, 'accepted_risk |]),
# which reject the plain strings a pure-data YAML instance necessarily carries.
# Worse, the `Findings` gate compares `f.status == 'mitigated`; a raw "mitigated"
# string never matches, so the gate would silently pass an ungrounded resolution.
# This adapter lifts those known strings to the tags the law expects BEFORE the
# law runs. Every valid value is a valid tag, so the lift is lossless and no
# invariant is weakened — only the YAML-string / Nickel-enum gap is bridged.
let c = import "findings.ncl" in

let lift_severity = match {
  "critical" => 'critical,
  "high" => 'high,
  "medium" => 'medium,
  "low" => 'low,
  x => x,
} in
let lift_status = match {
  "open" => 'open,
  "planned" => 'planned,
  "mitigated" => 'mitigated,
  "accepted_risk" => 'accepted_risk,
  x => x,
} in
let coerce = fun value =>
  value
  & {
    findings | force =
      std.array.map
        (fun f =>
          f
          & {
            severity | force = lift_severity f.severity,
            status | force = lift_status f.status,
          })
        value.findings,
  }
in

std.contract.custom (fun label value =>
  std.contract.check c.Findings label (coerce value)
)
