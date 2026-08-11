# Findings-ledger contract. A findings ledger is the SURVEY output: each entry
# is an evidence-grounded finding with a severity and a lifecycle status.
#
# EXTENDS THE ENTRY CORE (entry.ncl): a finding is a claim, and the reform
# gives it what every claim carries — a signer (who identified it) and an `at`
# anchor (the record state it was found against, so a file:line that has
# shifted is detectable rather than silently stale). The evaluator field moves
# from a bare name to a core Check anchor: naming a mechanism and having RUN
# it are different states, and only the second closes a finding.
#
# Intrinsic gate (C2, the Verification Dual made unforgeable): a finding may
# not reach a RESOLVED status ('mitigated or 'accepted_risk) unless its
# evaluator names the closing check AND that check was run. `nickel export`
# exits non-zero on a resolved finding whose evaluator is absent or unrun.
# Every enum comparison goes through the core's `matches` (ruling D-8): YAML
# carries strings, and a bare tag comparison against them is silently false —
# the gate would pass ungrounded resolutions without it.
#
# Edges (`depends`/`because`) point at related ledger ENTRIES by id; they are
# consequence-typed by the core but not resolved intra-store — the findings
# ledger is not the entry corpus they resolve in.
let e = import "entry.ncl" in
{
  # Value-restricted tag-or-string enums (ruling D-6), named so a shape red
  # carries its own token.
  Severity = std.contract.custom (fun _label v =>
    if e.matches v 'critical "critical" || e.matches v 'high "high"
       || e.matches v 'medium "medium" || e.matches v 'low "low"
    then 'Ok v
    else 'Error { message = "Severity: expected critical|high|medium|low (tag or string)" }
  ),

  Status = std.contract.custom (fun _label v =>
    if e.matches v 'open "open" || e.matches v 'planned "planned"
       || e.matches v 'mitigated "mitigated"
       || e.matches v 'accepted_risk "accepted_risk"
    then 'Ok v
    else 'Error { message = "Status: expected open|planned|mitigated|accepted_risk (tag or string)" }
  ),

  # The closing check: a core Check + the optional E-4 dirty marker.
  EvaluatorAnchor = e.Check & { dirty | Bool | optional },

  # One finding. `evaluator` names the strongest applicable evaluator that
  # grounds (or will ground) this finding's resolution; absent is only
  # permitted while the finding is still OPEN or PLANNED.
  Finding = {
    id | e.NonEmptyString,
    severity | Severity,
    statement | e.NonEmptyString,    # the evidence-grounded claim
    evidence | e.NonEmptyString,     # tool output, file:line, failing check
    status | Status,
    evaluator | EvaluatorAnchor | optional,
    signer | e.Signer,               # who identified this finding
    at | e.CommitRef,                # the record state it was found against
    depends | Array e.Ref | optional,
    because | Array e.Ref | optional,
  },

  # The resolution gate as a bare boolean (the core's batch-validation
  # design), lifted through `asContract` so the red names its predicate.
  is_resolved | doc "true iff the finding is at a resolved lifecycle status"
    = fun f =>
      e.matches f.status 'mitigated "mitigated"
      || e.matches f.status 'accepted_risk "accepted_risk",

  # A resolved finding must name a closing check that WAS RUN — the
  # exists/ran cut applied to resolution (a named-but-unrun evaluator is a
  # plan, not a closure).
  ResolutionRun = fun f =>
    !(is_resolved f)
    || (std.record.has_field "evaluator" f && f.evaluator.ran),

  # The per-finding contract the ledger applies: shape, then the gate.
  FindingChecked = std.contract.all_of [
    Finding,
    e.asContract "ResolutionRun" ResolutionRun,
  ],

  # The ledger contract: a record holding an array of findings, with
  # per-finding conformance (eager, the laziness guard) and id uniqueness
  # enforced intrinsically.
  Findings = std.contract.custom (fun _label value =>
    let findings = value.findings in
    let _conformance =
      std.array.fold_left
        (fun acc f => std.deep_seq (f | FindingChecked) acc)
        null
        findings
    in
    let ids = std.array.map (fun f => f.id) findings in
    let dedup =
      std.array.fold_left
        (fun acc x => if std.array.elem x acc then acc else acc @ [x])
        []
        ids
    in
    let unique_ids = std.array.length ids == std.array.length dedup in
    std.seq _conformance (
      if !unique_ids then 'Error { message = "duplicate finding id" }
      else 'Ok value
    )
  ),
}
