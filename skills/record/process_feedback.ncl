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
# EXTENDS THE ENTRY CORE (ledger/contracts/entry.ncl): feedback is a claim
# about what happened in the process, so it carries a signer (who observed it)
# and an `at` anchor (the record state the observation was made against). The
# category model — `kind`, with AMENDMENT's higher bar than improvement — is
# the record's own and stays.
#
# Instance format: YAML (validated via:
#   nickel export <file>.yaml --apply-contract skills/record/process_feedback_apply.ncl)
let e = import "../../ledger/contracts/entry.ncl" in
{
  # Kind: friction = the process caused unnecessary resistance;
  #       miss = a signal was missed, process didn't catch it;
  #       improvement = a refinement that made the process better;
  #       amendment = the agent changed the process and it was a good idea
  #                   (higher bar than improvement — a live rule was revised).
  # Value-restricted tag-or-string (ruling D-6) through the core's `matches`,
  # named so a shape red carries its own token.
  Kind = std.contract.custom (fun _label v =>
    if e.matches v 'friction "friction" || e.matches v 'miss "miss"
       || e.matches v 'improvement "improvement"
       || e.matches v 'amendment "amendment"
    then 'Ok v
    else 'Error { message = "Kind: expected friction|miss|improvement|amendment (tag or string)" }
  ),

  # One process-feedback record.
  ProcessFeedback = {
    id      | e.NonEmptyString,  # unique within the store
    kind    | Kind,              # friction | miss | improvement | amendment
    context | e.NonEmptyString,  # what situation triggered this feedback
    outcome | e.NonEmptyString,  # what changed or what it means for the process
    signer  | e.Signer,          # who observed it
    at      | e.CommitRef,       # the record state observed against
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
