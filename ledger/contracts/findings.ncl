# Findings-ledger contract. A findings ledger is the SURVEY output: each entry
# is an evidence-grounded finding with a severity and a lifecycle status.
#
# Intrinsic gate (C2, the Verification Dual made unforgeable): a finding may not
# reach a RESOLVED status ('mitigated or 'accepted_risk) with an empty evaluator
# field. Closing a finding requires naming the evaluator that closed it — the
# deterministic command or the adversarial-review record. `nickel export` exits
# non-zero on a resolved finding whose evaluator is "".
{
  # One finding. `evaluator` names the strongest applicable evaluator that
  # grounds (or will ground) this finding's resolution; "" means "not yet
  # grounded" and is only permitted while the finding is still OPEN or PLANNED.
  Finding = {
    id | String,
    severity | [| 'critical, 'high, 'medium, 'low |],
    statement | String,           # the evidence-grounded claim
    evidence | String,            # tool output, file:line, failing check
    status | [| 'open, 'planned, 'mitigated, 'accepted_risk |],
    evaluator | String,           # the gate that closes it; required once resolved
  },

  # The ledger contract: a record holding an array of findings, with the
  # resolved-requires-evaluator invariant enforced intrinsically.
  Findings = std.contract.custom (fun _label value =>
    let findings = value.findings in
    let is_resolved = fun f =>
      f.status == 'mitigated || f.status == 'accepted_risk
    in
    let grounded = fun f =>
      if is_resolved f then f.evaluator != "" else true
    in
    let ids = std.array.map (fun f => f.id) findings in
    let dedup =
      std.array.fold_left
        (fun acc x => if std.array.elem x acc then acc else acc @ [x])
        []
        ids
    in
    let unique_ids = std.array.length ids == std.array.length dedup in
    if !unique_ids then 'Error { message = "duplicate finding id" }
    else if !(std.array.all grounded findings)
    then 'Error { message = "resolved finding has empty evaluator (ungrounded)" }
    else 'Ok value
  ),
}
