# The ONE general procedure combinator (primitives-spec.md §P-COMPOSE).
#
# We do NOT author a state machine per skill — that would be a SMELL (no
# abstraction; every skill's composition scrutinised individually). We reason
# about ONE combinator, abstractly, ONCE:
#
#   procedure(required) = footprint-presence(required)        # the proven u1 spine
#                       ∘ per-step (leaf XOR invoke)           # I-C3 / I-C4 grammar
#                       ∘ invoke.class ∈ sub_procedures        # the no-spaghetti gate
#                       ∘ invoke deposits a resolving ref      # I-C2 composition-by-ref
#
# Every skill INHERITS these properties by supplying ONLY its required-step set
# (the F-REQ pattern, pinned UPSTREAM and un-shrinkable). The combinator is
# proved here once; per-skill correctness is then `procedure SKILLS_REQUIRED`.
#
# WHAT THIS BUILDS ON (do not regress):
#   - u1-draft/procedure.ncl proved footprint-presence + required-set-pinned-
#     upstream + the shrink-attack fix (required is a CONTRACT parameter, never an
#     instance field the walk can empty). That spine is reproduced in `complete`.
#   - deposit.ncl (P-GROUND) supplies the Evidence and DepositRef shapes; an
#     `invoke`'s ref is a real DepositRef so provenance is COMPOSED, not asserted.
#   - sub_procedures.ncl supplies the gated upstream registry; `invoke.class` is
#     checked against it, so an out-of-registry invocation is a forbidden state
#     caught structurally (I-C3) — machine-detectable spaghetti.
#
# ALTITUDE (I-C4): only the SKELETON + seams are gated. A step's creative interior
# stays prose — a step earns a contract field iff it has a checkable pre/post
# (id, kind, the leaf/invoke payload). Nothing here constrains WHAT a leaf step
# reasons; only THAT it deposited evidence, or THAT an invoke targets a registered
# class with a resolving ref.
#
# Contracts / values exported:
#   Step       — one procedure step: leaf{evidence,cites} XOR invoke{class,ref}
#   procedure  — the COMBINATOR: required-step-set -> a Procedure contract
#   CoreSteps  — the universal CORE-step ids lifted by the promotion pass
#   Procedure  — procedure CoreSteps : the always-on core every skill composes with
#
# Verification:
#   CONTRACT DEFINITIONS (this file): nickel typecheck
#   INSTANCE / FIXTURE: nickel export (with -I pointing to this directory)
let deposit = import "deposit.ncl" in
let sub_procedures = import "sub_procedures.ncl" in
{
  NonEmptyString = std.contract.from_predicate (fun value =>
    std.is_string value && std.string.length value > 0
  ),

  # ── Step ─────────────────────────────────────────────────────────────────────
  # One procedure step. `kind` is the discriminant of a tagged union; the custom
  # contract below enforces the XOR per step (the adversarial-finding resolution:
  # a state that does local work AND invokes is SPLIT INTO TWO states — the
  # grammar is not relaxed, so exactly one payload shape is legal per step).
  #
  #   'leaf   — does local work: deposits `evidence` (non-empty array of
  #             P-GROUND Evidence) + `cites` (paths). MUST NOT carry an invoke
  #             payload (no `class`, no `ref`).
  #   'invoke — calls a shared sub-procedure: carries `class` (∈ the gated
  #             registry) + `ref` (a P-GROUND DepositRef resolving to that
  #             sub-procedure's footprint — composition checked, not asserted).
  #             MUST NOT carry a leaf payload (no `evidence`).
  #
  # The record is OPEN (`..`) so human-facing prose (title, rationale, the step's
  # creative interior) rides alongside untouched — that is the altitude line.
  Step = std.contract.custom (fun _label value =>
    let has = fun f => std.record.has_field f value in
    # I-C3 / I-C4 — XOR by discriminant. Each branch checks BOTH the required
    # payload of its kind AND the absence of the other kind's payload, so a step
    # cannot smuggle both (it must be split). All field forcings happen inside the
    # branch so a malformed payload fails eagerly under the per-step deep_seq.
    value.kind
    |> match {
      'leaf =>
        if has "class" || has "ref"
        then 'Error { message = "a 'leaf step must not carry an invoke payload (class/ref); split it into two states" }
        else if !(has "evidence")
        then 'Error { message = "a 'leaf step must deposit non-empty `evidence`" }
        else
          # Force the leaf payload shapes: evidence is a non-empty array of
          # P-GROUND Evidence; cites is an array of paths. deep_seq makes the
          # nested Evidence contract (and its NonEmptyString fields) fire.
          let _ev_nonempty =
            (value.evidence
              | std.contract.from_predicate (fun v =>
                  std.is_array v && std.array.length v > 0))
          in
          let _ev_conformance =
            std.array.fold_left
              (fun acc e => std.deep_seq (e | deposit.Evidence) acc)
              null
              value.evidence
          in
          let _cites = (value.cites | Array String) in
          std.deep_seq _ev_nonempty (
            std.seq _ev_conformance (
              std.deep_seq _cites ('Ok value)
            )
          ),
      'invoke =>
        if has "evidence"
        then 'Error { message = "an 'invoke step must not carry a leaf payload (evidence); split it into two states" }
        else if !(has "class")
        then 'Error { message = "an 'invoke step must name a `class` from the sub-procedure registry" }
        else if !(has "ref")
        then 'Error { message = "an 'invoke step must deposit a `ref` resolving to the sub-procedure footprint (I-C2)" }
        else
          # I-C3: class ∈ the gated upstream registry (forbidden state otherwise).
          # I-C2: ref is a real P-GROUND DepositRef (composition by ref, not assertion).
          let _class = (value.class | sub_procedures.SubProcedure) in
          let _ref = (value.ref | deposit.DepositRef) in
          std.deep_seq _class (
            std.deep_seq _ref ('Ok value)
          ),
    }
  ),

  # ── the COMBINATOR ───────────────────────────────────────────────────────────
  # `procedure required` returns a Procedure contract over an instance
  # `{ workflow, steps }`. `required` is a CONTRACT PARAMETER fixed per workflow
  # UPSTREAM (the u1-draft F-REQ fix): it is NEVER an instance field, so the gated
  # walk authors `steps` only and cannot shrink the discriminating set. Properties
  # the returned contract enforces, ALL eager:
  #   (1) per-step Step conformance  — the leaf XOR invoke grammar + registry gate
  #   (2) footprint-presence         — every id in `required` appears in `steps`
  #   (3) id uniqueness              — no two steps share an id
  procedure = fun required =>
    std.contract.custom (fun _label value =>
      let steps = value.steps in
      # (1) Per-step grammar conformance (eager). deep_seq forces each Step's
      # branch — a malformed leaf/invoke payload or an out-of-registry class fails
      # the export rather than being skipped by laziness (the proven dag.ncl idiom).
      let _step_conformance =
        std.array.fold_left
          (fun acc s => std.deep_seq (s | Step) acc)
          null
          steps
      in
      let ids = std.array.map (fun s => s.id) steps in
      # (2) Footprint-presence: every UPSTREAM-required step id is present. This is
      # the proven u1 spine — `required` cannot be emptied by the walk because it
      # is bound here, outside the instance.
      let complete =
        std.array.all
          (fun req => std.array.any (fun x => x == req) ids)
          required
      in
      # (3) Id uniqueness (a duplicate id would let one footprint masquerade as two).
      let dedup =
        std.array.fold_left
          (fun acc x => if std.array.elem x acc then acc else acc @ [x])
          []
          ids
      in
      let unique_ids = std.array.length ids == std.array.length dedup in
      std.seq _step_conformance (
        if !unique_ids
        then 'Error { message = "duplicate procedure step id" }
        else if !complete
        then 'Error { message = "procedure omits an upstream-required step (footprint-presence)" }
        else 'Ok value
      )
    ),

  # ── CoreSteps — the universal core lifted by the promotion pass ───────────────
  # The PROMOTION pass (primitives-spec.md §P-COMPOSE) lifts skill-buried-but-
  # universal concerns OUT of single skills INTO the combinator core, so EVERY
  # procedure inherits them — not just the skill that happened to emphasise one.
  # Canonical hits:
  #   "track"             — P-TRACK's un-skippable R/I/U re-surfacing (made a
  #                          required core deposit so no walk passes without a fresh
  #                          tracker — resolves the "most important invariant
  #                          unenforced" gap).
  #   "adversarial-review" — emphasised in /refine but a PREMISE of the whole
  #                          system (the Verification Dual's soft path); lifts to
  #                          the core so every procedure invokes it.
  # These ride at the FRONT of the composition: procedure(skill) = CoreSteps ∘
  # skill-specific-required. A skill's full required-set is `CoreSteps @ skill_req`.
  CoreSteps = ["track", "adversarial-review"],

  # The always-on core contract every skill composes with. A concrete skill's
  # Procedure is `procedure (CoreSteps @ skill_specific_required)` — the core is
  # never shrinkable (it is part of the upstream-pinned set), so non-skip of the
  # universal concerns is guaranteed by the SAME footprint-presence proof.
  Procedure = procedure CoreSteps,
}
