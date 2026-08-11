# Reconcile-log contract. The reconcile log is appended once per reconciliation
# round: it records how each landed node was judged, each node's premise
# freshness, the realignments made, and the flight-recorder checkpoint commit.
#
# EXTENDS THE ENTRY CORE (entry.ncl): the round already had genuine event
# grounding (`checkpoint_commit`); the reform pushes that anchoring down to the
# individual judgment. Each Judgment now carries `at` — the state that was
# JUDGED, which the round-level checkpoint cannot supply (a node's definition
# can change between rounds, staling a judgment invisibly) — and an `author`
# (core Signer): who made this judgment. The Round structure is preserved.
#
# Intrinsic gate (C2, the Verification Dual): an 'accept verdict is the
# reconcile analog of a resolved finding — accepting landed work requires
# naming the evaluator/gate that justified acceptance. `nickel export` exits
# non-zero on an 'accept judgment whose evaluator is "". Rework and escalate
# carry no such requirement (they do not close anything). The comparison goes
# through the core's `matches` (ruling D-8): YAML carries strings, and a bare
# `j.verdict == 'accept` against them is silently false — the gate would pass
# every ungrounded acceptance without it.
let e = import "entry.ncl" in
{
  # Value-restricted tag-or-string enums (ruling D-6), named so a shape red
  # carries its own token.
  Verdict = std.contract.custom (fun _label v =>
    if e.matches v 'accept "accept" || e.matches v 'rework "rework"
       || e.matches v 'escalate "escalate"
    then 'Ok v
    else 'Error { message = "Verdict: expected accept|rework|escalate (tag or string)" }
  ),

  FreshState = std.contract.custom (fun _label v =>
    if e.matches v 'fresh "fresh" || e.matches v 'stale "stale"
    then 'Ok v
    else 'Error { message = "FreshState: expected fresh|stale (tag or string)" }
  ),

  # How one node was judged this round.
  Judgment = {
    node | e.NonEmptyString,
    verdict | Verdict,
    evaluator | String,           # the gate that justified the verdict; required on accept
    at | e.CommitRef,             # the state that was judged (per-judgment anchor)
    author | e.Signer,            # who made this judgment
  },

  # One node's premise-freshness status this round.
  Freshness = {
    node | e.NonEmptyString,
    state | FreshState,
  },

  # The acceptance gate as a bare boolean (the core's batch-validation
  # design), lifted through `asContract` so the red names its predicate.
  JudgmentGrounded = fun j =>
    !(e.matches j.verdict 'accept "accept") || j.evaluator != "",

  # The per-judgment contract each round applies: shape, then the gate.
  JudgmentChecked = std.contract.all_of [
    Judgment,
    e.asContract "JudgmentGrounded" JudgmentGrounded,
  ],

  # One reconciliation round. `judged` applies shape AND gate per judgment —
  # the single application point, so a deleted gate is a green mutation, not
  # a silently-redundant one.
  Round = {
    round | Number,
    judged | Array JudgmentChecked,
    freshness | Array Freshness,
    realignments | Array String,  # what changed in plan/orchestration and why
    checkpoint_commit | e.CommitRef,   # the .ledger/log flight-recorder hash
  },

  # The log contract: an array of rounds, each applied eagerly (the laziness
  # guard — `std.contract.apply` alone stays lazy and a malformed judgment
  # slips through `nickel export`).
  ReconcileLog = std.contract.custom (fun _label value =>
    let rounds = value.rounds in
    let _conformance =
      std.array.fold_left
        (fun acc r => std.deep_seq (r | Round) acc)
        null
        rounds
    in
    std.seq _conformance ('Ok value)
  ),
}
