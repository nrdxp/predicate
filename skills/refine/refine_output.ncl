# /refine output contract (P4 gap: /refine had no output contract).
#
# The refine workflow converges to a fixed-point S* and emits a REPORT record
# that a downstream agent or human can inspect to verify completion. This
# contract specifies the load-bearing shape of that REPORT, following the
# TWO-PURPOSE principle (primitives-spec.md §P-GROUND): each sub-field answers
# one question a reviewer would ask anyway; the machine gates presence +
# typing, the reviewer judges substance.
#
# EXTENDS THE ENTRY CORE (ledger/contracts/entry.ncl): the report's judgments
# are VOUCHES, and a vouch is testimony — an EVENT with a named party and the
# record state it certified. Each maintainer judgment carries a core Witness
# (name + at); the postmortem names its auditor the same way (the
# measurement's "auditor unnamed" fix — prose reference is not provenance).
# The refined targets are `depends` references (core edge typing): deleting a
# target breaks the report's fixed-point claim, which is exactly what the
# depends kind means.
#
# Fields and their reviewer-checkable semantics:
#
#   workflow          — the slug identifying which artifact was refined
#   depends           — the refined files (non-empty; a report with no named
#                       targets is vacuous)
#   final_loop        — the loop count k at convergence (> 0; k=0 means the
#                       loop never ran, a protocol violation)
#   consecutive_clean_sweeps — M_sweep consecutive clean MBSS passes (> 0)
#   maintainer_judgments — one VOUCH per maintainer panel member: role,
#                       verdict, and the witness event. All must be 'approved
#                       before REPORT is reachable (EXIT_GATE_INVARIANCE).
#   postmortem        — the Adversarial Process Auditor's structured critique,
#                       signed: critique text + the auditor's witness event
#   fixed_point_hash  — the SHA-256 hash of the workspace files at S*
#                       (monotone by design: the hash does not age)
#
# Verification:
#   CONTRACT DEFINITIONS (this file): nickel typecheck
#   INSTANCE / FIXTURE: nickel export (fixtures apply RefineReport then
#   RefineOutput; YAML via skills/refine/refine_output_apply.ncl)
let e = import "../../ledger/contracts/entry.ncl" in
{
  # Value-restricted tag-or-string (ruling D-6) through the core's `matches`,
  # named so a shape red carries its own token.
  MaintainerVerdict = std.contract.custom (fun _label v =>
    if e.matches v 'approved "approved" || e.matches v 'pending "pending"
    then 'Ok v
    else 'Error { message = "MaintainerVerdict: expected approved|pending (tag or string)" }
  ),

  # ── MaintainerJudgment — a vouch ─────────────────────────────────────────────
  # `role` is the persona slug (e.g. "maintainer-architecture"); `witness` is
  # the core vouch event: who testified, against which record state.
  MaintainerJudgment = {
    role    | e.NonEmptyString,
    verdict | MaintainerVerdict,
    witness | e.Witness,
  },

  # ── Postmortem — the auditor's signed critique ───────────────────────────────
  Postmortem = {
    critique | e.NonEmptyString,
    witness  | e.Witness,        # the auditor, named as provenance not prose
  },

  # ── RefineReport — the output record shape ────────────────────────────────────
  RefineReport = {
    workflow                  | e.NonEmptyString,
    depends                   | Array e.Ref,   # the refined targets (edge-typed)
    final_loop                | Number,
    consecutive_clean_sweeps  | Number,
    maintainer_judgments      | Array MaintainerJudgment,
    postmortem                | Postmortem,
    fixed_point_hash          | e.NonEmptyString,
  },

  # ── RefineOutput — the intrinsic gate ─────────────────────────────────────────
  # Applied AFTER RefineReport (composing shape + integrity):
  #   value | RefineReport | RefineOutput
  # Enforces:
  #   (a) depends non-empty
  #   (b) final_loop > 0
  #   (c) consecutive_clean_sweeps > 0
  #   (d) maintainer_judgments non-empty, all 'approved (via the core
  #       `matches` — a YAML "approved"/"pending" enforces identically)
  # Substance (was the postmortem adequate? were the targets real?) → review.
  RefineOutput = std.contract.custom (fun _label value =>
    let targets_present =
      std.is_array value.depends
      && std.array.length value.depends > 0
    in
    let loop_ran = value.final_loop > 0 in
    let converged = value.consecutive_clean_sweeps > 0 in
    let all_approved =
      std.array.all
        (fun j => e.matches j.verdict 'approved "approved")
        value.maintainer_judgments
    in
    let has_maintainers =
      std.is_array value.maintainer_judgments
      && std.array.length value.maintainer_judgments > 0
    in
    if !targets_present
    then 'Error { message = "RefineOutput: depends must be non-empty (a nameless refinement is meaningless)" }
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
