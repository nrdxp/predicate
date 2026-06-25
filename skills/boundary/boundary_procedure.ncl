# /boundary procedure contract.
#
# Instantiates the ONE general procedure combinator (procedure.ncl) for the
# boundary workflow. The boundary workflow's innermost state machine is:
#
#   DRAFT ──→ ATTACK ──→ REVISE ──→ APPROVE
#              └─────────────────────────────┘  (loop until zero grounded objections)
#
# Required-step set (upstream-pinned, un-shrinkable):
#   CoreSteps ("track", "adversarial-review")  ←  universal core lifted by promotion pass
#   + ["draft", "attack", "revise", "approve"] ←  boundary-specific workflow spine
#
# Composition pattern (from primitives-spec.md §P-COMPOSE):
#   boundary_procedure = procedure (CoreSteps @ boundary_required)
#                      ∘ WorkerIBC (output contract: the boundary produces an IBC*)
#
# The output contract (WorkerIBC) is applied AFTER the procedure spine, composing
# both checks so `nickel export` gates the full boundary: step footprints present
# AND the output IBC* shape is well-formed with a non-empty goal and ≥1 acceptance
# criterion.
#
# Relative imports (resolved from this file's own directory: skills/boundary/).
#   ../../ledger/contracts/procedure.ncl  — the proven combinator (CoreSteps, procedure)
#   ../../ledger/contracts/worker_ibc.ncl — the output contract (Worker, WorkerIBC)
#
# Contracts exported:
#   BoundaryRequired   — the boundary-specific required-step ids
#   BoundaryProcedure  — the procedure combinator pinned to the full boundary set
#   BoundaryOutput     — alias for worker_ibc.WorkerIBC (the IBC* output shape)
#
# Verification:
#   nickel typecheck skills/boundary/boundary_procedure.ncl
#   nickel export ledger/fixtures/boundary_procedure_honest.ncl
#   nickel export ledger/fixtures/boundary_procedure_skip.ncl     # must fail
#   nickel export ledger/fixtures/boundary_procedure_fake.ncl     # passes; flagged for review
let proc_mod     = import "../../ledger/contracts/procedure.ncl" in
let worker_mod   = import "../../ledger/contracts/worker_ibc.ncl" in
{
  # ── Boundary-specific required steps ─────────────────────────────────────────
  # Pinned UPSTREAM in this contract (F-REQ). The walk authors `steps` only and
  # cannot shrink this set. "draft" through "approve" map one-to-one to the four
  # states of the boundary refinement loop (boundary/SKILL.md §The Boundary
  # Refinement Loop).
  BoundaryRequired = ["draft", "attack", "revise", "approve"],

  # ── Full required set (core + boundary-specific) ─────────────────────────────
  # Used internally and exported so fixtures can reference it without repeating
  # the concatenation.
  FullRequired = proc_mod.CoreSteps @ BoundaryRequired,

  # ── BoundaryProcedure — the spine contract ────────────────────────────────────
  # `procedure (CoreSteps @ BoundaryRequired)` enforces:
  #   (1) per-step leaf XOR invoke grammar (I-C3 / I-C4)
  #   (2) footprint-presence for all 6 required ids
  #   (3) id uniqueness across steps
  BoundaryProcedure = proc_mod.procedure FullRequired,

  # ── BoundaryOutput — the IBC* output shape ───────────────────────────────────
  # The boundary workflow's output is a WorkerIBC (the refined IBC* it emits).
  # Aliased here so callers compose:
  #   value | Worker | WorkerIBC | BoundaryProcedure
  # or equivalently:
  #   value | BoundaryOutput | BoundaryProcedure
  BoundaryOutput = worker_mod.WorkerIBC,
}
