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
# The five views:
#
#   awaiting_human — OPEN questions whose closer designates a human: the work
#                    only the head can clear. Reads `closer.kind` — a lookup
#                    on the designation record, not a match against prose.
#                    EXCLUDES `residual`: a residual question is open by
#                    THEOREM, never by an outstanding task, so it names no
#                    clearable work and does not belong in a work queue —
#                    docs/entries.md's residual section. It may carry a
#                    `closer` anyway (QuestionRoutable no longer requires one,
#                    but does not forbid one either, node/ran-and-residual),
#                    so the exclusion is on `backing`, never inferred from the
#                    field's absence.
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
#   chain_floor    — where each claim's support BOTTOMS OUT, following
#                    derivation edges transitively. `unbacked` answers this
#                    one hop deep, which is the wrong depth: a claim can name
#                    a well-formed edge and still rest on a proposal three
#                    hops down, and reading that off the record by hand is
#                    what makes an agent reach for an invented confidence
#                    number instead. Three floors, and a claim may have
#                    several because support branches: `closed` (a
#                    corroborated or vouched leaf), `unbacked` (an unclosed
#                    leaf with no support at all), `external` (support that
#                    left the corpus, so the record cannot follow it).
#
# The parameterized TAG selector (ledger/log/2026-08-12-tagging-hypothesis.md
# [G4]: ten of eleven wanted queries are tag SET OPERATIONS, not traversal).
# node/tag-query's dispatch: the head's actual requirement is COMPOSITION —
# "all records under this direction / under these directions with these
# tags / with these tags in any direction" — and a fixed enumeration of
# arity-1 and arity-2 cases cannot compose past two, let alone mix a
# direction tag with a topical one. This file used to carry four such
# enumerated views (by_tag, by_direction, co_occurrence, untagged); the first
# three are CUT below in favor of the one selector that subsumes them all.
#
#   with_tags(required) — deterministic set intersection: every entry
#                    carrying ALL of `required`, arity-free (one tag, two, or
#                    N), spanning direction and topical tags in the SAME
#                    namespace, since tag_registry.ncl keeps one coining bar
#                    rather than two. Subsumes by_tag (the one-element case),
#                    by_direction (that filtered to the registry's
#                    `category = "direction"` subset), and co_occurrence (the
#                    two-element case, no longer bounded to PAIRS of
#                    REGISTERED tags alone) — each was a fixed-arity copy of
#                    the same intersection, and cutting them is licensed by
#                    the project's `molten` maturity (AGENTS.md): no consumer
#                    existed yet to preserve.
#
#                    A tag outside the registry is REFUSED (`Array
#                    law.TagName` blames) — the coining bar's enforcement
#                    half binds a query the same as it binds an entry. A
#                    registered-but-unused tag answers `[]`, never an error —
#                    the registry, never the corpus's own tags, is what
#                    admits a name, so an admitted-but-idle tag is a real,
#                    honestly-empty answer rather than an absent key. The
#                    EMPTY required set answers with EVERY entry: an
#                    intersection over zero constraints excludes nothing, the
#                    vacuous-AND identity `std.array.all` already gives an
#                    empty predicate list — the case needs no special branch,
#                    it falls out of the general formula.
#
#                    Exported `| not_exported`: a function cannot serialize
#                    to JSON, so a bare `--apply-contract` run never sees
#                    `with_tags` in its output. It is reached by applying
#                    this contract to a corpus INSIDE a small Nickel
#                    expression and calling `.with_tags [...]` before THAT
#                    result is exported — see test_entries_extract.sh's
#                    with_tags cases for the exact invocation shape.
#
#   untagged       — the absence query, unchanged, and still the one that
#                    matters most: entries carrying no `tags` field at all,
#                    or an empty one. Against the live, still-untagged corpus
#                    this returns EVERY entry — the honest starting state,
#                    not a bug the view should hide.
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

      # --- chain floors ---------------------------------------------------
      #
      # Where each claim's support bottoms out, following derivation edges
      # transitively (`walk`, defined below `leaf_floor`). Whether an entry
      # names an external antecedent is read straight off its own `because`
      # array (ruling-provenance-representation [SR2]): the sidecar join
      # this used to reassemble by hand, at read time, is gone — the tag
      # travels with the ref itself.
      let has_external = fun e =>
        std.array.any
          (fun r => law.matches r.kind 'external "external")
          (law.refs_of "because" e)
      in
      let is_closed_evidence = fun e =>
        is_claim e
        && (law.matches e.backing 'corroborated "corroborated"
            || law.matches e.backing 'vouched "vouched")
      in
      # The leaf verdict, for an entry whose support the walk cannot continue
      # through — either because the entry IS the floor, or because it has no
      # derivation edges to follow.
      let leaf_floor = fun e =>
        if is_closed_evidence e then { closed = true }
        else if has_external e then { external = true }
        else { unbacked = true }
      in
      # This used to be a ROUND-BASED fixed point: one pass over every
      # corpus entry, repeated until nothing changed. "Iterate to
      # convergence instead of N unconditional passes" turns out to need
      # more than a smarter loop bound: EVERY round-based fixed point tried
      # here (whole-record `==`, a monotone-sum proxy, a blind fixed round
      # count, restricting each round to only the entries that can still
      # move) reconstructs the WHOLE floors record on EVERY round, and
      # measured against the live corpus that reconstruction is what
      # exhausts memory — independent of round count (two rounds over the
      # full corpus is fine; four is not) and independent of per-round
      # payload size (plain integers hit the same wall). A GLOBAL record
      # threaded through repeated whole-corpus folds is the shared culprit
      # across every variant, so the fix replaces the shape rather than
      # tuning it further: `walk` is a
      # PER-CLAIM bounded DFS along `corpus_edges_of`, with no floors record
      # threaded across a round boundary at all. `visiting` is the
      # cycle-breaker EntryStore's acyclicity gap requires (a `because`
      # cycle would otherwise diverge): a cycle member reached while it is
      # already on the current walk's stack contributes nothing FROM THAT
      # EDGE, matching the fixed-point reading exactly — an entry reached by
      # a SEPARATE, non-cyclic path still contributes normally, which is why
      # two claims deriving from each other in a cycle can still both
      # resolve `closed` through a shared ancestor neither edge of the cycle
      # itself supplies. A directive resolves via `by_id`'s absence check —
      # it is never in `entries`, closes by authority rather than evidence,
      # and contributes nothing to a union it is walked into
      # (ruling-terminal-composition [TC5] widens `depends`/`because` to
      # legitimately name one).
      let by_id =
        std.array.fold_left (fun acc e => std.record.insert e.id e acc) {} entries
      in
      let rec walk = fun visiting id =>
        if !(std.record.has_field id by_id) then
          {}
        else if std.record.has_field id visiting then
          {}
        else
          let e = by_id."%{id}" in
          let edges = law.corpus_edges_of e in
          if is_closed_evidence e || std.array.length edges == 0 then
            leaf_floor e
          else
            let visiting_here = std.record.insert id true visiting in
            std.array.fold_left
              (fun u r => add_all u (std.record.fields (walk visiting_here r)))
              (if has_external e then { external = true } else {})
              edges
      in

      # --- tags -------------------------------------------------------------
      #
      # `has_tag`/`tags_of` read straight off the entry. The registry
      # (`law.tag_registry`, via `law.TagName`) governs WHICH tags a query
      # may name — `with_tags` below is where that gate is applied — not
      # which ones this lookup indexes, so no registry-keyed structure is
      # built here at all.
      let tags_of = fun e => get_or "tags" [] e in
      let has_tag = fun t e => std.array.any (fun x => x == t) (tags_of e) in
      'Ok {
        awaiting_human =
          entries
          |> std.array.filter (fun e =>
            is_question e
            && is_open e
            && !(law.matches e.backing 'residual "residual")
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
            let inbound = law.corpus_edges_of e in
            let ext =
              law.refs_of "because" e
              |> std.array.filter (fun r => law.matches r.kind 'external "external")
              |> std.array.map (fun r => r.name)
            in
            {
              id = e.id,
              statement = e.statement,
              edges = inbound,
              external_refs = ext,
              backed = std.array.length inbound > 0,
            }),
        chain_floor =
          entries
          |> std.array.filter is_claim
          |> std.array.map (fun e =>
            { id = e.id, floors = std.record.fields (walk {} e.id) }),
        with_tags | not_exported = fun required =>
          let checked = required | Array law.TagName in
          entries
          |> std.array.filter (fun e => std.array.all (fun t => has_tag t e) checked)
          |> std.array.map (fun e => e.id),
        untagged =
          entries
          |> std.array.filter (fun e => std.array.length (tags_of e) == 0)
          |> std.array.map (fun e => e.id),
      },
  }
)
