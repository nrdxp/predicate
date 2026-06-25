# CORE-step registry — the universal steps lifted by the promotion pass.
#
# Primitive: P-COMPOSE (primitives-spec.md §P-COMPOSE, "The PROMOTION pass").
#
# The promotion pass sweeps skills/*/SKILL.md for concerns that are EMPHASIZED
# in one skill but actually UNIVERSAL (bind every walk). Those concerns lift
# OUT of the skill into this file — the single source of truth for the
# combinator's core:
#
#   procedure(skill) = CORE-steps  ∘  skill-specific-required  ∘  sub-procedure-refs
#                                  ∘  output-contract
#
# SWEEP RESULT — skills surveyed: 32 (all skills/*/SKILL.md in the worktree).
# Promotion criterion: the concern MUST bind every walk with no triggering
# condition; skill-specific or conditionally-triggered concerns are NOT promoted.
#
# ── PROMOTED (2 universals confirmed) ────────────────────────────────────────
#
#   "track"
#     What:   P-TRACK's un-skippable R/I/U re-surfacing.  Every active task
#             MUST maintain a live four-quadrant tracker (Requirements /
#             Invariants / Known-unknowns / Unknown-unknowns) and RE-SURFACE
#             it at each step — absence = the whole task is an unknown-unknown.
#     Source: skills/record/SKILL.md   — "absence = failure (the task is then
#               all-unknown-unknown)" (P-TRACK I-T1).
#             primitives-spec.md §P-TRACK — "Re-surfacing made UN-SKIPPABLE:
#               Promote … to a CORE-step of the P-COMPOSE combinator … a walk
#               cannot pass its footprint contract without a fresh tracker."
#             rules.md §7 — "Boundary reconstruction: re-read this file and
#               the active sketchpad ledger" at every long-horizon step.
#             ambient.md §Boundary Reconstruction — standing discipline,
#               never not active.
#     Why universal: every walk operates against some task goal; the tracker
#       is how the walk stays coherent about that goal. No triggering condition.
#
#   "adversarial-review"
#     What:   Decorrelated, context-free review — the Verification Dual's soft
#             path. Closes conditions where no deterministic evaluator exists.
#             Every artifact-producing procedure invokes it; a single reviewer
#             sharing the generator's attractor basin cannot close soft-path
#             conditions.
#     Source: skills/refine/SKILL.md   — owns and emphasizes the MBSS /
#               AUDIT phase most explicitly.
#             rules.md §2 Invariant 1 — "if none [deterministic evaluator]
#               can exist, the condition is closed by adversarial review from
#               context-free agents operating out of decorrelated boundaries."
#             rules.md §4 — "One-Shot Skepticism", "Iteration Transparency",
#               "Grounded Critique — dual grounding": adversarial review
#               governs EVERY artifact exit.
#             skills/ai-audit/SKILL.md — the adversarial-path methodology.
#             skills/api-audit/SKILL.md, skills/security-audit/SKILL.md,
#               skills/git-review/SKILL.md — each anchors itself to the
#               adversarial path of the Verification Dual, confirming the
#               review step is universal, not skill-specific.
#     Why universal: every generated artifact has soft-path conditions (adequacy,
#       purpose-fit, coherence-with-goal); deterministic evaluators close only
#       structural conditions. No triggering condition on the review step itself.
#
# ── SWEPT AND NOT PROMOTED ────────────────────────────────────────────────────
#
#   "prior-art"     — rules.md §4.6 requires ≥2 references for NON-TRIVIAL
#                     algorithms; the prior-art skill itself scopes to
#                     "non-trivial algorithms, protocols, or major library
#                     integrations."  The trigger is a CONDITION on design
#                     complexity, not every walk.  Already a registered
#                     sub-procedure class in sub_procedures.ncl (an invoke).
#
#   "discovery"     — a sub-procedure invoked conditionally by P-ARSENAL
#                     (when selecting a capability-class member).  Not every
#                     procedure involves an arsenal selection step.  Already
#                     in sub_procedures.ncl.
#
#   "commit-gate"   — the Commit Gate (rules.md §3) fires at commit boundaries,
#                     not as a procedure step within a skill walk.  Skills that
#                     do NOT make commits (doc-audit, ai-audit, api-audit, etc.)
#                     have no commit step.  Not universal across every walk.
#
#   "premise-verification" — S1–S2 of the boundary skill run once at the
#                     boundary before dispatch; NOT a recurring step inside
#                     the procedure combinator.  Embedded in boundary/SKILL.md.
#
#   "intent-recovery" — P-INTENT's checkable residue is omission-only +
#                     a weak goal-overlap check; it is "almost entirely
#                     (A)-territory" (primitives-spec.md §P-INTENT).  Captured
#                     at the boundary level (S1–S7 IBC), not a recurring
#                     combinator step.
#
#   "outward-search" — ambient.md Outward-Search Reflex fires conditionally
#                     (before halting on an unresolved dilemma), not on every
#                     procedure step.
#
#   "boundary-reconstruction" — collapses into "track": the tracker IS the
#                     freshness mechanism; re-surfacing the tracker satisfies
#                     rules.md §7's step-start reconstruction mandate.
#
# ── Contracts exported ────────────────────────────────────────────────────────
#   core_steps   — Array String: the canonical list of promoted CORE-step ids.
#   CoreSteps    — same value, exported under the capitalized name for
#                  direct consumption by procedure.ncl's combinator.
#
# Verification:
#   nickel typecheck -I ledger/contracts ledger/contracts/core_steps.ncl
#   nickel typecheck -I ledger/contracts ledger/contracts/procedure.ncl
{
  # The canonical, upstream-pinned list of promoted CORE-step ids.  Adding a
  # step here is a privileged, human-approved edit — the un-self-authored
  # property that governs every discriminating set in the combinator.
  # Consumers (procedure.ncl) reference CoreSteps and may prepend it to a
  # skill's specific required-set: `CoreSteps @ skill_required`.
  core_steps = [
    "track",            # P-TRACK un-skippable R/I/U re-surfacing
    "adversarial-review", # Verification Dual soft path (decorrelated review)
  ],

  # Capitalized alias: procedure.ncl's CoreSteps constant references this.
  CoreSteps = core_steps,
}
