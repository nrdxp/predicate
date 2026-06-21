# Context-map contract — the LIVE carrier of a walk's active requirements and
# unknowns (CONTRACT.md "Carrier roles"). Where AGENTS.md is the slow-changing
# persistent anchor and the flight log is narrative history, the context-map is
# current state: what the walk is actively holding, each item carrying the
# evidence that grounds it, when it was last checked against reality, and the
# signpost that would resolve or defeat it.
#
# Intrinsic gate (the Verification Dual made unforgeable): an item that omits —
# or empties — its `grounding`, `last_validated`, or `signpost` is a silent
# omission, the exact failure this carrier exists to kill. `nickel export` exits
# non-zero on any such item, so the single portable command IS the gate; a
# headless walk cannot carry an ungrounded requirement forward unnoticed.
#
# Unknowns are first-class, treated exactly like requirements (CONTRACT.md): the
# same `Item` shape carries both. `signpost` reads as "what would resolve or
# invalidate this" for an 'unknown, and "what would defeat this" for the others —
# one field, both meanings, never empty.
{
  # A non-empty string. The empty string is the silent-omission sentinel, so it
  # is rejected here rather than at each call site. `std.contract.from_predicate`
  # raises EAGERLY when the value is forced, which the per-element `std.deep_seq`
  # in `ContextMap` (below) guarantees — so a "" or omitted field fails the
  # export rather than being skipped by laziness.
  NonEmptyString = std.contract.from_predicate (fun value =>
    std.is_string value && std.string.length value > 0
  ),

  # One context-map item. A requirement, invariant, constraint, or live unknown.
  # `grounding`, `last_validated`, and `signpost` are mandatory and non-empty:
  # the contract makes naming the evidence, the freshness, and the defeater a
  # precondition of carrying the item at all.
  Item = {
    id | String,
    statement | String,                  # the requirement/unknown itself
    kind | [| 'requirement, 'invariant, 'constraint, 'unknown |],
    grounding | NonEmptyString,          # source/evidence; "" forbidden
    last_validated | NonEmptyString,     # when last checked vs reality; "" forbidden
    signpost | NonEmptyString,           # resolver (unknown) / defeater (others); "" forbidden
  },

  # The context-map contract: a record holding an array of items, with the
  # every-item-grounded invariant enforced intrinsically.
  ContextMap = std.contract.custom (fun _label value =>
    let items = value.items in
    # Per-element item conformance: annotate each item with the `Item` contract
    # so the field shapes, the `kind` enum, AND the NonEmptyString fields are
    # actually enforced. A contract defined but never applied is inert. The
    # annotation form `(it | Item)` under `std.deep_seq` raises the violation
    # EAGERLY — `std.contract.apply` alone stays lazy and a bad item slips
    # through `nickel export`. deep_seq descends into the annotated fields so an
    # empty `grounding` (or an omitted required field, or an out-of-enum `kind`)
    # fails the export rather than being skipped.
    let _item_conformance =
      std.array.fold_left
        (fun acc it => std.deep_seq (it | Item) acc)
        null
        items
    in
    let ids = std.array.map (fun it => it.id) items in
    let dedup =
      std.array.fold_left
        (fun acc x => if std.array.elem x acc then acc else acc @ [x])
        []
        ids
    in
    let unique_ids = std.array.length ids == std.array.length dedup in
    # `std.seq _item_conformance` forces the per-element `Item` applications
    # before the structural verdict, so a malformed item fails the contract
    # eagerly rather than being skipped by laziness.
    std.seq _item_conformance (
      if !unique_ids then 'Error { message = "duplicate context-map item id" }
      else 'Ok value
    )
  ),
}
