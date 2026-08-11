# P-GROUND deposit substrate (primitives-spec.md §P-GROUND).
#
# Every other primitive issues DEPOSITS; this contract specifies what a deposit
# IS, how its evidence is structured so a reviewer has grip, and how deposits
# cross-reference each other with referential integrity enforced intrinsically.
#
# TWO-PURPOSE PRINCIPLE (primitives-spec.md): the schema is the reviewer's
# checklist formalized. Each sub-field answers one question a reviewer would ask
# anyway; the machine verifies presence + typing, the reviewer judges substance.
#
# EXTENDS THE ENTRY CORE (entry.ncl): the flat method enum used to rank the two
# evidence species — corroboration (a re-runnable check that WAS RUN) and vouch
# (a named admitted witness) — as peer values, which made any admission policy
# unimplementable: nothing said whether a named mechanism was executed, or who
# stood behind a judgement. Reformed, every evidence item carries its signer and
# the anchor its species requires: methods that are deterministic mechanisms
# carry a core `Check` (command, ran, at); methods that are judgements carry a
# core `Witness` (name, at). The method field is KEPT — it is the evaluator-tier
# information the species alone does not carry.
#
# Contracts exported:
#   CheckAnchor / WitnessAnchor — core Check/Witness + the optional E-4 dirty
#                   marker (absent = tree matched `at`; true = ran against `at`
#                   plus uncommitted changes)
#   Evidence      — one reviewer-checkable sub-claim, signed, species-anchored
#   EvidenceChecked — Evidence composed with the two species predicates
#   DepositRef    — typed pointer to a deposit by id, with an explicit role
#   Deposit       — the P-GROUND footprint record
#   DepositStore  — intrinsic referential-integrity gate over an array of deposits
#
# Verification:
#   CONTRACT DEFINITIONS (this file): nickel typecheck
#   INSTANCE / FIXTURE: nickel export <f>.yaml --apply-contract deposit_apply.ncl
let e = import "entry.ncl" in
{
  # Re-exported core sentinel: discovery.ncl destructures NonEmptyString from
  # this module; the definition lives in the core alone. (procedure.ncl and
  # arsenal_registry.ncl declare their own local NonEmptyString copies rather
  # than importing this one — not this module's re-export to describe.)
  NonEmptyString = e.NonEmptyString,

  # The core anchors, extended with the OPTIONAL dirty marker (E-4). Record
  # merge extends the frozen core without editing it; the merged record stays
  # closed (an undeclared extra field is still rejected).
  CheckAnchor = e.Check & { dirty | Bool | optional },
  WitnessAnchor = e.Witness & { dirty | Bool | optional },

  # Value-restricted tag-or-string (the D-6 idiom, via the core's `matches`):
  # the evaluator tier of one evidence item. review/manual are vouch-species;
  # everything else is corroboration-species (see the two predicates below).
  EvidenceMethod = std.contract.custom (fun _label v =>
    if e.matches v 'proof "proof"
       || e.matches v 'type_check "type_check"
       || e.matches v 'property_test "property_test"
       || e.matches v 'example_test "example_test"
       || e.matches v 'lint "lint"
       || e.matches v 'review "review"
       || e.matches v 'manual "manual"
    then 'Ok v
    else 'Error { message = "EvidenceMethod: expected proof|type_check|property_test|example_test|lint|review|manual (tag or string)" }
  ),

  # One reviewer-checkable sub-claim. `claim` = WHAT is asserted; `method` =
  # the evaluator tier; `location` = WHERE to reproduce or refute it; `signer`
  # = WHO asserts it (core Signer — the universal R3 gap, closed); the anchor
  # (`check` or `witness`) = the species-shaped backing itself.
  Evidence = {
    claim | e.NonEmptyString,
    method | EvidenceMethod,
    location | e.NonEmptyString,
    signer | e.Signer,
    check | CheckAnchor | optional,
    witness | WitnessAnchor | optional,
  },

  # The method-to-species cut. Bare boolean predicates (the core's batch-
  # validation design), lifted through the core's `asContract` so each red
  # names its own predicate.
  is_vouch_method | doc "true iff the method is judgement-species (review/manual)"
    = fun m => e.matches m 'review "review" || e.matches m 'manual "manual",

  # A judgement-species item must name its witness — testimony without a named
  # admitted party is not a vouch.
  VouchSpeciesWitnessed = fun ev =>
    !(is_vouch_method ev.method) || std.record.has_field "witness" ev,

  # A mechanism-species item must carry a check that WAS RUN — a named-but-
  # unrun mechanism is a dispatchable question, not evidence (the core's
  # corroborated/unclosed cut, applied at the evidence grain).
  CorroborationSpeciesRan = fun ev =>
    is_vouch_method ev.method
    || (std.record.has_field "check" ev && ev.check.ran),

  # The per-item contract the store applies: shape first, then the two species
  # predicates (each failure carries its own token).
  EvidenceChecked = std.contract.all_of [
    Evidence,
    e.asContract "VouchSpeciesWitnessed" VouchSpeciesWitnessed,
    e.asContract "CorroborationSpeciesRan" CorroborationSpeciesRan,
  ],

  # ── DepositRef ──────────────────────────────────────────────────────────────
  # A typed pointer from this deposit to another deposit by id. The `role` field
  # names WHY the reference exists (what relationship it expresses), giving
  # reviewers the context to judge whether the provenance claim is apt.
  DepositRef = {
    target | String,             # the id of the referenced deposit
    role   | e.NonEmptyString,   # e.g. "discovery-footprint", "prior-work", "sub-procedure-output"
  },

  # At least one evidence item — a deposit with no sub-claims is vacuous.
  # Named custom (not from_predicate) so the red carries its own token.
  NonEmptyEvidence = std.contract.custom (fun _label v =>
    if std.is_array v && std.array.length v > 0
    then 'Ok v
    else 'Error { message = "Deposit.evidence: at least one evidence item required" }
  ),

  # ── Deposit ──────────────────────────────────────────────────────────────────
  # The P-GROUND footprint record. Invariants enforced at the record level:
  #   I-G1  id non-empty; evidence a non-empty array
  # Per-item Evidence conformance and referential integrity (I-G2) are enforced
  # at the store level by DepositStore.
  Deposit = {
    id       | e.NonEmptyString,       # unique within the instance
    step     | e.NonEmptyString,       # the procedure step that wrote this deposit
    evidence | NonEmptyEvidence,       # array of Evidence; per-item check in the store
    cites    | Array String,           # file paths cited as supporting material
    refs     | Array DepositRef,       # typed pointers to other deposits (DepositRef)
  },

  # ── DepositStore ─────────────────────────────────────────────────────────────
  # Intrinsic referential-integrity gate over an array of deposits. Enforces:
  #   (a) per-element Deposit conformance (eager via std.deep_seq) — Deposit's
  #       `refs | Array DepositRef` field means this fold already forces every
  #       DepositRef; no separate per-ref fold is needed or present
  #   (b) per-element EvidenceChecked conformance — shape + the two species
  #       predicates — within each deposit's evidence (eager)
  #   (c) id uniqueness (I-G1)
  #   (d) every ref.target resolves to a declared deposit id (I-G2)
  #
  # The `std.deep_seq (n | Contract) acc` annotation is what makes the contract
  # EAGER — `std.contract.apply` alone stays lazy and violations slip through
  # `nickel export`. `std.seq _conformance` forces the fold before the verdict.
  DepositStore = std.contract.custom (fun _label value =>
    let deposits = value.deposits in

    # (a) Per-deposit shape conformance (Deposit contract, eager). Forces every
    # DepositRef in `refs` as a side effect of forcing the Deposit shape.
    let _deposit_conformance =
      std.array.fold_left
        (fun acc d => std.deep_seq (d | Deposit) acc)
        null
        deposits
    in

    # (b) Per-evidence conformance inside each deposit (eager).
    let _nested_conformance =
      std.array.fold_left
        (fun acc d =>
          std.array.fold_left
            (fun a2 ev => std.deep_seq (ev | EvidenceChecked) a2)
            acc
            d.evidence)
        null
        deposits
    in

    let ids = std.array.map (fun d => d.id) deposits in

    # (c) Id uniqueness.
    let dedup =
      std.array.fold_left
        (fun acc x => if std.array.elem x acc then acc else acc @ [x])
        []
        ids
    in
    let unique_ids = std.array.length ids == std.array.length dedup in

    # (d) Referential integrity: every ref.target must be a declared deposit id.
    let all_refs_resolve =
      std.array.all
        (fun d =>
          std.array.all
            (fun r => std.array.elem r.target ids)
            d.refs)
        deposits
    in

    # Force both conformance checks before the structural verdict so a malformed
    # deposit or nested field fails eagerly — not silently passed by laziness.
    std.seq _deposit_conformance (
      std.seq _nested_conformance (
        if !unique_ids
        then 'Error { message = "duplicate deposit id" }
        else if !all_refs_resolve
        then 'Error { message = "dangling DepositRef: ref.target does not resolve to a declared deposit id" }
        else 'Ok value
      )
    )
  ),
}
