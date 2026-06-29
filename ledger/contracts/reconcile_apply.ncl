# Apply-contract for reconcile logs authored as pure-data YAML instances.
#
# Usage (from the project root, with the shell.nix nickel on PATH):
#   nickel export <reconcile_log>.yaml --apply-contract ledger/contracts/reconcile_apply.ncl
#
# reconcile_log.ncl is the law and stays UNCHANGED. Its top-level `ReconcileLog`
# contract carries the intrinsic gate: a judgment with an 'accept verdict and an
# empty `evaluator` makes `nickel export` exit non-zero — accepting landed work
# requires naming the gate that justified it.
#
# YAML→tag adapter: Judgment.verdict ([| 'accept, 'rework, 'escalate |]) and
# Freshness.state ([| 'fresh, 'stale |]) are BARE enum contracts that reject the
# plain strings a pure-data YAML instance carries. Worse, the `ReconcileLog` gate
# compares `j.verdict == 'accept`; a raw "accept" string never matches, so the
# gate would silently pass an ungrounded acceptance. This adapter lifts those
# known strings to the tags the law expects BEFORE the law runs — lossless, since
# every valid value is a valid tag, and no invariant is weakened.
let c = import "reconcile_log.ncl" in

let lift_verdict = match {
  "accept" => 'accept,
  "rework" => 'rework,
  "escalate" => 'escalate,
  x => x,
} in
let lift_state = match {
  "fresh" => 'fresh,
  "stale" => 'stale,
  x => x,
} in
let coerce = fun value =>
  value
  & {
    rounds | force =
      std.array.map
        (fun r =>
          r
          & {
            judged | force =
              std.array.map (fun j => j & { verdict | force = lift_verdict j.verdict }) r.judged,
            freshness | force =
              std.array.map (fun f => f & { state | force = lift_state f.state }) r.freshness,
          })
        value.rounds,
  }
in

std.contract.custom (fun label value =>
  std.contract.check c.ReconcileLog label (coerce value)
)
