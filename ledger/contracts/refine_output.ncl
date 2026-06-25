# /refine output contract (P4 gap: /refine had no output contract).
#
# The refine workflow converges to a fixed-point S* and emits a REPORT record
# that a downstream agent or human can inspect to verify completion. This contract
# specifies the load-bearing shape of that REPORT, following the TWO-PURPOSE
# principle (primitives-spec.md §P-GROUND): each sub-field answers one question
# a reviewer would ask anyway; the machine gates presence + typing, the reviewer
# judges substance.
#
# Fields and their reviewer-checkable semantics:
#
#   workflow          — the slug identifying which artifact was refined (presence)
#   target_artifacts  — the files that were in CTX.TARGET_ARTIFACTS (non-empty;
#                       a report with no named targets is vacuous)
#   final_loop        — the loop count k at convergence (> 0; k=0 means the loop
#                       never ran, which is a protocol violation)
#   consecutive_clean_sweeps — M_sweep consecutive clean MBSS passes reached (> 0;
#                       a report with 0 clean sweeps has not converged)
#   maintainer_judgments — one entry per maintainer panel member: role + verdict.
#                       All must be 'approved before REPORT is reachable (invariant
#                       EXIT_GATE_INVARIANCE). Non-empty array required.
#   postmortem        — the Adversarial Process Auditor's structured critique
#                       (non-empty string; the process was not audited if absent)
#   fixed_point_hash  — the SHA-256 hash of the workspace files at S* (non-empty;
#                       ties the report to a concrete artifact state)
#
# Intrinsic gates:
#   - target_artifacts non-empty (a nameless refinement is meaningless)
#   - final_loop > 0 (the loop ran at least once)
#   - consecutive_clean_sweeps > 0 (convergence was verified)
#   - all maintainer_judgments carry verdict 'approved (EXIT_GATE_INVARIANCE)
#
# Verification:
#   CONTRACT DEFINITIONS (this file): nickel typecheck
#   INSTANCE / FIXTURE: nickel export (with -I pointing to ledger/contracts)
{
  # Non-empty string sentinel — mirrors deposit.ncl / context_map.ncl pattern.
  NonEmptyString = std.contract.from_predicate (fun value =>
    std.is_string value && std.string.length value > 0
  ),

  # ── MaintainerJudgment ───────────────────────────────────────────────────────
  # One maintainer's verdict. `role` is the persona slug (e.g.
  # "maintainer-architecture"); `verdict` must be 'approved (any 'pending means
  # the report was premature).
  MaintainerJudgment = {
    role    | NonEmptyString,
    verdict | [| 'approved, 'pending |],
  },

  # ── RefineReport — the output record shape ────────────────────────────────────
  RefineReport = {
    workflow                  | NonEmptyString,
    target_artifacts          | Array String,
    final_loop                | Number,
    consecutive_clean_sweeps  | Number,
    maintainer_judgments      | Array MaintainerJudgment,
    postmortem                | NonEmptyString,
    fixed_point_hash          | NonEmptyString,
  },

  # ── RefineOutput — the intrinsic gate ─────────────────────────────────────────
  # Applied AFTER RefineReport (composing shape + integrity):
  #   value | RefineReport | RefineOutput
  # Enforces:
  #   (a) target_artifacts non-empty
  #   (b) final_loop > 0
  #   (c) consecutive_clean_sweeps > 0
  #   (d) all maintainer judgments carry verdict 'approved
  # Substance (was the postmortem adequate? were the targets real?) → review.
  RefineOutput = std.contract.custom (fun _label value =>
    let targets_present =
      std.is_array value.target_artifacts
      && std.array.length value.target_artifacts > 0
    in
    let loop_ran = value.final_loop > 0 in
    let converged = value.consecutive_clean_sweeps > 0 in
    let all_approved =
      std.array.all
        (fun j => j.verdict == 'approved)
        value.maintainer_judgments
    in
    let has_maintainers =
      std.is_array value.maintainer_judgments
      && std.array.length value.maintainer_judgments > 0
    in
    if !targets_present
    then 'Error { message = "RefineOutput: target_artifacts must be non-empty" }
    else if !loop_ran
    then 'Error { message = "RefineOutput: final_loop must be > 0 (loop never ran)" }
    else if !converged
    then 'Error { message = "RefineOutput: consecutive_clean_sweeps must be > 0 (no convergence verified)" }
    else if !has_maintainers
    then 'Error { message = "RefineOutput: maintainer_judgments must be non-empty" }
    else if !all_approved
    then 'Error { message = "RefineOutput: all maintainer_judgments must carry verdict 'approved (EXIT_GATE_INVARIANCE)" }
    else 'Ok value
  ),
}
