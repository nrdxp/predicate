# Reconcile-log contract. The reconcile log is appended once per reconciliation
# round: it records how each landed node was judged, each node's premise
# freshness, the realignments made, and the flight-recorder checkpoint commit.
#
# Intrinsic gate (C2, the Verification Dual): an 'accept verdict is the reconcile
# analog of a resolved finding — accepting landed work requires naming the
# evaluator/gate that justified acceptance. `nickel export` exits non-zero on an
# 'accept judgment whose evaluator is "". Rework and escalate carry no such
# requirement (they do not close anything).
{
  # How one node was judged this round.
  Judgment = {
    node | String,
    verdict | [| 'accept, 'rework, 'escalate |],
    evaluator | String,           # the gate that justified the verdict; required on accept
  },

  # One node's premise-freshness status this round.
  Freshness = {
    node | String,
    state | [| 'fresh, 'stale |],
  },

  # One reconciliation round.
  Round = {
    round | Number,
    judged | Array Judgment,
    freshness | Array Freshness,
    realignments | Array String,  # what changed in plan/orchestration and why
    checkpoint_commit | String,   # the .sketches flight-recorder hash
  },

  # The log contract: an array of rounds with the accept-requires-evaluator
  # invariant enforced intrinsically across every judgment in every round.
  ReconcileLog = std.contract.custom (fun _label value =>
    let rounds = value.rounds in
    let judgment_grounded = fun j =>
      if j.verdict == 'accept then j.evaluator != "" else true
    in
    let round_grounded = fun r => std.array.all judgment_grounded r.judged in
    if !(std.array.all round_grounded rounds)
    then 'Error { message = "accepted node has empty evaluator (ungrounded acceptance)" }
    else 'Ok value
  ),
}
