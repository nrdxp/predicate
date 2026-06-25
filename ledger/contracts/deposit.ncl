# P-GROUND deposit substrate (primitives-spec.md §P-GROUND).
#
# Every other primitive issues DEPOSITS; this contract specifies what a deposit
# IS, how its evidence is structured so a reviewer has grip, and how deposits
# cross-reference each other with referential integrity enforced intrinsically.
#
# TWO-PURPOSE PRINCIPLE (primitives-spec.md): the schema is the reviewer's
# checklist formalized. Each sub-field answers one question a reviewer would ask
# anyway; the machine verifies presence + typing, the reviewer judges substance.
# A single free-text blob fails both layers: the machine only checks "non-empty"
# and the reviewer gets a blank page. The structured evidence below gives both
# grip.
#
# Contracts exported:
#   Evidence      — one reviewer-checkable sub-claim
#   DepositRef    — typed pointer to a deposit by id, with an explicit role
#   Deposit       — the P-GROUND footprint record (5 required top-level fields)
#   DepositStore  — intrinsic referential-integrity gate over an array of deposits
#                   (ids unique; every ref.target resolves to a declared id)
#
# Composition pattern (mirrors dag.ncl / context_map.ncl):
#   value | Deposit             — individual deposit shape check
#   value | Deposit | DepositRef — individual ref shape check (on a ref record)
#   { deposits = [...] } | DepositStore   — full store with referential integrity
#
# Verification:
#   CONTRACT DEFINITIONS (this file): nickel typecheck
#   INSTANCE / FIXTURE: nickel export (with -I pointing to this directory)
{
  # Non-empty string: the silent-omission sentinel (empty string) is rejected
  # here so call sites are clean. `std.contract.from_predicate` raises eagerly
  # when the value is forced under `std.deep_seq`.
  NonEmptyString = std.contract.from_predicate (fun value =>
    std.is_string value && std.string.length value > 0
  ),

  # ── Evidence ────────────────────────────────────────────────────────────────
  # The reviewer's checklist for ONE sub-claim within a deposit. Each field
  # answers a distinct question:
  #   claim    → WHAT is asserted (the falsifiable sub-claim)
  #   method   → HOW it was established (determines the evaluator tier)
  #   location → WHERE to look to reproduce or refute it (a file:line, command,
  #              URL, or commit hash — not a narrative)
  #
  # Structured into three fields rather than one free-text blob because:
  #   - The machine can gate each field non-empty independently.
  #   - The reviewer can judge claim / method / location as distinct quality axes.
  #   - A mis-typed method fails the contract; a mis-typed free-text blob passes.
  # Value-restricted tag-or-string for Evidence.method.
  # Accepts the enum tag 'proof/'type_check/… OR the matching string "proof"/
  # "type_check"/… so a YAML deposit (which carries strings, not tags) validates
  # without modification.  A bare [| 'proof, … |] rejects strings; a bare
  # std.enum.TagOrString accepts ANY string and loses the value restriction.
  # This contract implements: string ∈ allowed-set OR matching tag — the minimum
  # that preserves both the YAML-compatibility and the value-restriction goals.
  EvidenceMethod = std.contract.from_predicate (fun v =>
    v == 'proof          || v == "proof"
    || v == 'type_check  || v == "type_check"
    || v == 'property_test || v == "property_test"
    || v == 'example_test  || v == "example_test"
    || v == 'lint        || v == "lint"
    || v == 'review      || v == "review"
    || v == 'manual      || v == "manual"
  ),

  Evidence = {
    claim    | NonEmptyString,   # the falsifiable assertion
    method   | EvidenceMethod,   # how it was established; accepts tag or string
    location | NonEmptyString,   # file:line, command, URL, or commit to reproduce
  },

  # ── DepositRef ──────────────────────────────────────────────────────────────
  # A typed pointer from this deposit to another deposit by id. The `role` field
  # names WHY the reference exists (what relationship it expresses), giving
  # reviewers the context to judge whether the provenance claim is apt.
  DepositRef = {
    target | String,             # the id of the referenced deposit
    role   | NonEmptyString,     # e.g. "discovery-footprint", "prior-work", "sub-procedure-output"
  },

  # ── Deposit ──────────────────────────────────────────────────────────────────
  # The P-GROUND footprint record. Invariants enforced at the record level:
  #   I-G1  id and evidence non-empty (NonEmptyString + Evidence contract)
  #   I-G1  evidence is a non-empty array (at least one sub-claim)
  # Referential integrity (I-G2) is enforced at the store level by DepositStore.
  Deposit = {
    id       | NonEmptyString,         # unique within the instance
    step     | NonEmptyString,         # the procedure step that wrote this deposit
    evidence | std.contract.from_predicate (fun v =>
                 std.is_array v && std.array.length v > 0
               ),                      # array of Evidence; non-empty enforced here
    cites    | Array String,           # file paths cited as supporting material
    refs     | Array DepositRef,       # typed pointers to other deposits (DepositRef)
  },

  # ── DepositStore ─────────────────────────────────────────────────────────────
  # Intrinsic referential-integrity gate over an array of deposits. Enforces:
  #   (a) per-element Deposit conformance (eager via std.deep_seq)
  #   (b) per-element DepositRef conformance within each deposit's refs (eager)
  #   (c) per-element Evidence conformance within each deposit's evidence (eager)
  #   (d) id uniqueness (I-G1)
  #   (e) every ref.target resolves to a declared deposit id (I-G2)
  #
  # Pattern mirrors dag.ncl's Dag contract exactly:
  #   std.array.fold_left (fun acc n => std.deep_seq (n | Node) acc) null nodes
  # The `std.deep_seq (n | Contract) acc` annotation is what makes the contract
  # EAGER — `std.contract.apply` alone stays lazy and violations slip through
  # `nickel export`. `std.seq _conformance` forces the fold before the verdict.
  DepositStore = std.contract.custom (fun _label value =>
    let deposits = value.deposits in

    # (a) Per-deposit shape conformance (Deposit contract, eager).
    let _deposit_conformance =
      std.array.fold_left
        (fun acc d => std.deep_seq (d | Deposit) acc)
        null
        deposits
    in

    # (b+c) Per-ref and per-evidence conformance inside each deposit (eager).
    # Iterating evidence sub-items and refs with deep_seq ensures the nested
    # NonEmptyString and enum contracts fire rather than being skipped lazily.
    let _nested_conformance =
      std.array.fold_left
        (fun acc d =>
          let _evs =
            std.array.fold_left
              (fun a2 ev => std.deep_seq (ev | Evidence) a2)
              acc
              d.evidence
          in
          std.array.fold_left
            (fun a3 r => std.deep_seq (r | DepositRef) a3)
            _evs
            d.refs)
        null
        deposits
    in

    let ids = std.array.map (fun d => d.id) deposits in

    # (d) Id uniqueness.
    let dedup =
      std.array.fold_left
        (fun acc x => if std.array.elem x acc then acc else acc @ [x])
        []
        ids
    in
    let unique_ids = std.array.length ids == std.array.length dedup in

    # (e) Referential integrity: every ref.target must be a declared deposit id.
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
