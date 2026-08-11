# Context-map contract — the LIVE carrier of a walk's active requirements and
# unknowns (CONTRACT.md "Carrier roles"). Where AGENTS.md is the slow-changing
# persistent anchor and the flight log is narrative history, the context-map is
# current state: what the walk is actively holding, each item carrying the
# evidence that grounds it, when it was last checked against reality, and what
# would resolve or defeat it.
#
# EXTENDS THE ENTRY CORE (entry.ncl) and the boundary's Directive (ruling E-3:
# preserve-and-express — the map's structure is PRESERVED, its rows expressed
# in core vocabulary rather than rebuilt):
#
#   - requirement/invariant/constraint rows ARE directives (ruling E-1): they
#     command rather than assert, so each is the boundary Directive record
#     merge-extended with the map's own carrier fields. Its authority is its
#     `provenance` signer; its `signpost` stays — the DEFEATER of a directive
#     is map metadata, not a question's discharge condition (which E-1 forbids
#     on directives).
#   - `unknown` rows are QUESTION ENTRIES: the core Entry merge-extended with
#     the same carrier fields. The old `signpost` maps onto the core
#     `discharge`, and the row GAINS the closer it always lacked — both
#     enforced by the core's own QuestionRoutable, inherited not restated.
#
# UNKNOWNS REMAIN FIRST-CLASS: one items array carries both row classes,
# dispatched by `kind` (the entry_apply shape-dispatch idiom).
#
# Intrinsic gate (the Verification Dual made unforgeable): an item that omits
# or empties its `grounding`, `last_validated`, or `signpost`/`discharge` is a
# silent omission, the exact failure this carrier exists to kill — `nickel
# export` exits non-zero on any such item. `last_validated` KEEPS its date
# semantics: tracker_fresh.sh compares it against the HEAD commit date, and
# that external interface may not silently break; the new `at` CommitRef
# anchors the item to record state, which a date cannot.
let e = import "entry.ncl" in
let b = import "worker_ibc.ncl" in
{
  # Value-restricted tag-or-string (ruling D-6; was a bare enum that rejected
  # every YAML string on arrival — the shim's lift is now unnecessary).
  Kind = std.contract.custom (fun _label v =>
    if e.matches v 'requirement "requirement" || e.matches v 'invariant "invariant"
       || e.matches v 'constraint "constraint" || e.matches v 'unknown "unknown"
    then 'Ok v
    else 'Error { message = "Kind: expected requirement|invariant|constraint|unknown (tag or string)" }
  ),

  # The carrier fields every row adds to its base record.
  #
  # `hydration_source` (P-TRACK / I14): OPTIONAL; when present it records the
  # AGENTS.md path#section this item was hydrated from. Absent/null = item
  # originated in scratch. Feeds tracker_fresh.sh: a stale `last_validated` on
  # a hydrated item means the persistent anchor may have drifted. The empty
  # string is the silent-omission sentinel and is forbidden.
  carrier_fields = {
    kind | Kind,
    grounding | e.NonEmptyString,        # source/evidence; "" forbidden
    last_validated | e.NonEmptyString,   # date last checked vs reality (tracker_fresh interface)
    at | e.CommitRef,                    # the record state the item was validated against
    hydration_source
      | std.contract.from_predicate (fun v => v == null || (std.is_string v && std.string.length v > 0))
      | optional
      | default = null,                  # AGENTS.md path#section; null = scratch-originated
  },

  # A requirement/invariant/constraint row: the boundary Directive plus the
  # carrier fields and its defeater. Closed by merge — `backing` or `axes` on
  # a directive row is still an extra-field rejection.
  RicItem =
    b.Directive
    & carrier_fields
    & { signpost | e.NonEmptyString },   # what would DEFEAT this; "" forbidden

  RicChecked = std.contract.all_of [
    RicItem,
    e.asContract "DirectiveDesignates" b.DirectiveDesignates,
  ],

  # An unknown row: a full core question entry plus the carrier fields. The
  # core's lifted predicates supply the routing rule (discharge AND closer)
  # and the signer discipline; UnknownIsQuestion blocks mis-filing a claim
  # under `kind: unknown` to dodge them.
  UnknownItem = e.Entry & carrier_fields,

  UnknownChecked = std.contract.all_of (
    [UnknownItem]
    @ e.lifted
    @ [e.asContract "UnknownIsQuestion" b.UnknownIsQuestion]
  ),

  # Per-item shape dispatch on `kind` (the entry_apply idiom).
  ItemChecked = std.contract.custom (fun label value =>
    if std.is_record value
       && std.record.has_field "kind" value
       && e.matches value.kind 'unknown "unknown"
    then std.contract.check UnknownChecked label value
    else std.contract.check RicChecked label value
  ),

  # The context-map contract: a record holding an array of items, dispatched
  # and applied EAGERLY per element (`std.contract.apply` alone stays lazy and
  # a bad item slips through `nickel export`), with id uniqueness enforced.
  ContextMap = std.contract.custom (fun _label value =>
    let items = value.items in
    let _item_conformance =
      std.array.fold_left
        (fun acc it => std.deep_seq (it | ItemChecked) acc)
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
    std.seq _item_conformance (
      if !unique_ids then 'Error { message = "duplicate context-map item id" }
      else 'Ok value
    )
  ),
}
