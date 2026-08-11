# The first queries over the typed-claim record — a Nickel evaluation over
# the extractor's export, invoked as a value-transforming contract:
#
#   nickel export <export>.yaml --apply-contract ledger/contracts/entries_query.ncl
#
# Validation is not re-implemented: the export runs through the EXISTING
# entry_apply.ncl before any view is computed, so an invalid corpus never
# yields a query result (a result over unvalidated data would be `proved`
# relative to nothing).
#
# OPENNESS is DERIVED, never authored: a question is open iff no entry in the
# corpus names it in a `discharges` or `supersedes` edge. Both question views
# filter on it, so a question that has been answered — or merged into a
# surviving duplicate — leaves the work lists by itself. Nothing marks a
# question closed by hand, which is the point: a status field would have to be
# maintained in step with the edges and would silently rot when it was not.
#
# The four views:
#
#   awaiting_human — OPEN questions whose closer designates a human: the work
#                    only the head can clear. Reads `closer.kind` — a lookup
#                    on the designation record, not a match against prose.
#   runnable_now   — OPEN questions the extractor graded `dispatchable`: a
#                    check exists and has not been run. Grades live in the
#                    export's sidecar because entries carry questions as
#                    `unclosed` (the entry fixtures' practice —
#                    CorroborationBacked and VouchBacked have no assertion
#                    guard); a corpus without the sidecar therefore answers
#                    with an empty view rather than a guessed one.
#   unpaid_cures   — claims whose axes demand a T3 cure nothing pays: a
#                    non-monotone claim without its freshness obligation, the
#                    cure text read from the law's own cure_for lookup. The
#                    `unassessed` half lists claims carrying no axes at all,
#                    so an empty violations list is never mistaken for a
#                    clean bill the record cannot support.
#   unbacked       — unclosed claims (the synthesis cell) with their
#                    provenance edges and any external refs the extractor
#                    preserved, so a claim with no inbound edge — the
#                    structural definition of a hallucination — is visible.
let apply = import "entry_apply.ncl" in
let law = import "entry.ncl" in

let get_or = fun name fallback r =>
  if std.record.has_field name r then r."%{name}" else fallback
in

std.contract.custom (fun label value =>
  std.contract.check apply label value
  |> match {
    'Error err => 'Error err,
    'Ok validated =>
      let entries = validated.entries in
      let grades = get_or "grades" {} validated in
      let externals = get_or "external_refs" [] validated in
      let is_question = fun e => law.matches e.assertion 'question "question" in
      let is_claim = fun e => law.matches e.assertion 'claim "claim" in
      let grade_of = fun e =>
        if std.record.has_field e.id grades then grades."%{e.id}" else ""
      in
      let question_view = fun e =>
        {
          id = e.id,
          statement = e.statement,
          discharge = get_or "discharge" null e,
          closer = get_or "closer" null e,
        }
      in

      # --- openness -------------------------------------------------------
      #
      # The set of ids some entry closes, as a record used as a set (the
      # id_set idiom the contract already uses): O(1) membership, so openness
      # is a lookup per question rather than a scan of the whole corpus.
      # EntryStore has already proved every one of these refs resolves, so a
      # member here is always a real entry.
      let add_all = fun acc refs =>
        std.array.fold_left
          (fun a r => if std.record.has_field r a then a else std.record.insert r true a)
          acc
          refs
      in
      let closed_ids =
        std.array.fold_left
          (fun acc e =>
            add_all acc (law.refs_of "discharges" e @ law.refs_of "supersedes" e))
          {}
          entries
      in
      let is_open = fun e => !(std.record.has_field e.id closed_ids) in

      'Ok {
        awaiting_human =
          entries
          |> std.array.filter (fun e =>
            is_question e
            && is_open e
            && std.record.has_field "closer" e
            && law.matches e.closer.kind 'human "human")
          |> std.array.map question_view,
        runnable_now =
          entries
          |> std.array.filter (fun e =>
            is_question e && is_open e && grade_of e == "dispatchable")
          |> std.array.map question_view,
        unpaid_cures = {
          violations =
            entries
            |> std.array.filter (fun e =>
              is_claim e
              && std.record.has_field "axes" e
              && !e.axes.monotone
              && !(std.record.has_field "freshness" e))
            |> std.array.map (fun e =>
              { id = e.id, statement = e.statement, cure = law.cure_for e.axes }),
          unassessed =
            entries
            |> std.array.filter (fun e =>
              is_claim e && !(std.record.has_field "axes" e))
            |> std.array.map (fun e => e.id),
        },
        unbacked =
          entries
          |> std.array.filter (fun e =>
            is_claim e && law.matches e.backing 'unclosed "unclosed")
          |> std.array.map (fun e =>
            let inbound = law.edges_of e in
            let ext =
              externals
              |> std.array.filter (fun x => x.entry == e.id)
              |> std.array.map (fun x => x.refs)
              |> std.array.flatten
            in
            {
              id = e.id,
              statement = e.statement,
              edges = inbound,
              external_refs = ext,
              backed = std.array.length inbound > 0,
            }),
      },
  }
)
