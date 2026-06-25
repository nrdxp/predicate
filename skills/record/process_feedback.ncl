# Process-feedback record contract (skills/record/process_feedback.ncl).
#
# A process-feedback record captures friction, a missed signal, an improvement,
# or an AMENDMENT (the agent changed the process and it was a good idea).
#
# Purpose: nrd mines these to improve predicate; downstream users contribute
# theirs back or evolve their own process. The AMENDMENT kind in particular
# makes process changes first-class and durable rather than living only in
# conversation recall.
#
# Instance format: YAML (validated via:
#   nickel export <file>.yaml --apply-contract skills/record/process_feedback_apply.ncl)
#
# `kind` uses the same value-restricted tag-or-string pattern as other enums in
# this codebase: a YAML string ("amendment") and a Nickel tag ('amendment) both
# satisfy the contract without modification.
{
  NonEmptyString = std.contract.from_predicate (fun v =>
    std.is_string v && std.string.length v > 0
  ),

  # Kind: friction = the process caused unnecessary resistance;
  #       miss = a signal was missed, process didn't catch it;
  #       improvement = a refinement that made the process better;
  #       amendment = the agent changed the process and it was a good idea
  #                   (higher bar than improvement — a live rule was revised).
  Kind = std.contract.from_predicate (fun v =>
    v == 'friction    || v == "friction"
    || v == 'miss       || v == "miss"
    || v == 'improvement || v == "improvement"
    || v == 'amendment  || v == "amendment"
  ),

  # One process-feedback record.
  ProcessFeedback = {
    id      | NonEmptyString,  # unique within the store
    kind    | Kind,             # friction | miss | improvement | amendment
    context | NonEmptyString,  # what situation triggered this feedback
    outcome | NonEmptyString,  # what changed or what it means for the process
  },

  # Store contract: validates an array of records with id uniqueness enforced.
  # Usage: { items = [...] } | ProcessFeedbackStore
  ProcessFeedbackStore = std.contract.custom (fun _label value =>
    let items = value.items in
    let ids = std.array.map (fun f => f.id) items in
    let dedup =
      std.array.fold_left
        (fun acc x => if std.array.elem x acc then acc else acc @ [x])
        []
        ids
    in
    let _conformance =
      std.array.fold_left
        (fun acc f => std.deep_seq (f | ProcessFeedback) acc)
        null
        items
    in
    std.seq _conformance (
      if std.array.length ids != std.array.length dedup
      then 'Error { message = "duplicate process-feedback id" }
      else 'Ok value
    )
  ),
}
