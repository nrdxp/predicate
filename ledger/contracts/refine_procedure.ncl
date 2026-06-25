# /refine procedure contract.
#
# Instantiates the ONE general procedure combinator (procedure.ncl) for the
# refine workflow. The refine workflow's innermost state machine is:
#
#   ABSORB ──→ CLARIFY? ──→ AUDIT ──→ ITERATE ──→ SWEEP ──→ REVIEW ──→ REPORT
#                              ↑___________|  (repeatable; loops until convergence)
#
# Required-step set (upstream-pinned, un-shrinkable):
#   CoreSteps ("track", "adversarial-review")  ←  universal core lifted by promotion
#   + ["absorb", "clarify", "audit", "iterate",
#      "sweep", "review", "report", "halt"]    ←  refine-specific workflow spine
#
# REPEATABLE STEPS (audit, iterate):
#   The combinator's footprint-presence check requires that an id from the
#   required-set appears AT LEAST ONCE in `steps`. For repeatable phases, the
#   FIRST occurrence bears the canonical id ("audit", "iterate"); subsequent
#   repetitions ride alongside under distinct ids ("audit-2", "iterate-2", …).
#   The contract sees the canonical id present and passes; the extra occurrences
#   do not violate uniqueness because they carry different ids. This is the
#   altitude line (I-C4): the combinator gates the skeleton (at least one deposit
#   per required step), not the loop count (which stays in prose / the TRACE).
#
# Composition pattern (from primitives-spec.md §P-COMPOSE):
#   refine_procedure = procedure (CoreSteps @ refine_required)
#                    ∘ RefineOutput (output contract: the refine walk emits a REPORT)
#
# BARE imports (resolved via the gate's -I ledger/contracts):
#   procedure.ncl    — the proven combinator (CoreSteps, procedure)
#   refine_output.ncl — the output contract (RefineReport, RefineOutput)
#
# Contracts exported:
#   RefineRequired    — the refine-specific required-step ids
#   FullRequired      — CoreSteps @ RefineRequired (convenience for fixtures)
#   RefineProcedure   — the procedure combinator pinned to the full refine set
#   RefineOutputAlias — alias for refine_output.RefineOutput (output shape)
#
# Verification:
#   nickel typecheck -I ledger/contracts ledger/contracts/refine_procedure.ncl
#   nickel export   -I ledger/contracts ledger/fixtures/refine_procedure_honest.ncl
#   nickel export   -I ledger/contracts ledger/fixtures/refine_procedure_skip.ncl    # must fail
#   nickel export   -I ledger/contracts ledger/fixtures/refine_procedure_fake.ncl    # passes; flagged for review
let proc_mod   = import "procedure.ncl" in
let output_mod = import "refine_output.ncl" in
{
  # ── Refine-specific required steps ───────────────────────────────────────────
  # Pinned UPSTREAM in this contract (F-REQ). Maps to the 8 named states in
  # refine/SKILL.md §State-Transitions: ABSORB, CLARIFY, AUDIT, ITERATE, SWEEP,
  # REVIEW, REPORT, HALT. The walk authors `steps` only; it cannot shrink this set.
  RefineRequired = [
    "absorb",
    "clarify",
    "audit",
    "iterate",
    "sweep",
    "review",
    "report",
    "halt",
  ],

  # ── Full required set (core + refine-specific) ────────────────────────────────
  FullRequired = proc_mod.CoreSteps @ RefineRequired,

  # ── RefineProcedure — the spine contract ──────────────────────────────────────
  # `procedure (CoreSteps @ RefineRequired)` enforces:
  #   (1) per-step leaf XOR invoke grammar (I-C3 / I-C4)
  #   (2) footprint-presence for all 10 required ids
  #   (3) id uniqueness across steps (extra repeatable occurrences use distinct ids)
  RefineProcedure = proc_mod.procedure FullRequired,

  # ── RefineOutputAlias — the REPORT output shape ───────────────────────────────
  # The refine workflow's output is a RefineOutput (the REPORT record). Aliased
  # here so callers compose:
  #   value | RefineReport | RefineOutput | RefineProcedure
  # or equivalently:
  #   value | RefineOutputAlias | RefineProcedure
  RefineOutputAlias = output_mod.RefineOutput,
}
