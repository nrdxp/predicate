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
# The four TAG views (ledger/log/2026-08-12-tagging-hypothesis.md [G4]: ten of
# eleven wanted queries are tag SET OPERATIONS, not traversal — these are
# them). Every one is a lookup over `law.tag_registry`
# (ledger/contracts/tag_registry.ncl), the coining bar's data half, so a view
# never invents a key the registry does not declare and an untagged corpus
# answers with real, honestly-empty results rather than an absent field.
#
#   by_tag         — membership: every registered tag mapped to the ids of
#                    entries carrying it, `[]` for a tag nothing carries yet.
#   by_direction   — the same index, restricted to the registry's
#                    `category = "direction"` subset: "everything constituting
#                    a direction" (D1, D2, D3) as a set operation rather than
#                    an unknowable, per the composer's dispatch. A strict
#                    projection of `by_tag`, not a second mechanism — TODAY
#                    every registered tag is a direction, so the two coincide
#                    extensionally until a non-direction tag is registered
#                    (tag_registry.ncl's own header states this is expected).
#   co_occurrence  — every unordered pair of registered tags, keyed
#                    `"<a>+<b>"` (`a < b`, so a pair has exactly one key), to
#                    the ids of entries carrying BOTH. Bounded by the
#                    registry's own size, not the corpus's — the coining bar
#                    keeps the vocabulary small by design, so the pairing is
#                    cheap precisely because admission was deliberate.
#   untagged       — the absence query, and the one that matters most: entries
#                    carrying no `tags` field at all, or an empty one. Against
#                    the live, still-untagged corpus this returns EVERY entry
#                    — the honest starting state, not a bug the view should
#                    hide.
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
      # A least-fixed-point over the derivation edges, computed by iterating
      # the one-step relation once per entry rather than by recursing: a
      # `because` cycle would make the recursive reading diverge, and the
      # record cannot rule cycles out (EntryStore requires resolution, not
      # acyclicity). N iterations reach the fixed point for any acyclic
      # chain, since no path is longer than the corpus; a cycle simply keeps
      # the empty floor set, which reads correctly as "bottoms out nowhere".
      # Whether an entry names an external antecedent is now read straight off
      # its own `because` array (ruling-provenance-representation [SR2]): the
      # sidecar join this used to reassemble by hand, at read time, is gone —
      # the tag travels with the ref itself.
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
      let step = fun prev =>
        std.array.fold_left
          (fun acc e =>
            let edges = law.corpus_edges_of e in
            let floors =
              if is_closed_evidence e || std.array.length edges == 0 then
                leaf_floor e
              else
                # Support BRANCHES at this entry: the edges are followed, and
                # the entry's own external refs are a branch beside them that
                # the walk cannot follow. Seeding the union carries that branch
                # INTO the fixed point, so anything deriving from this entry
                # inherits it; unioning it onto the assembled rows instead
                # would report the branch at the entry that names the ref and
                # lose it one hop down.
                std.array.fold_left
                  (fun u r => add_all u (std.record.fields prev."%{r}"))
                  (if has_external e then { external = true } else {})
                  edges
            in
            std.record.insert e.id floors acc)
          {}
          entries
      in
      let floors_of =
        std.array.fold_left
          (fun acc _e => step acc)
          (std.array.fold_left (fun acc e => std.record.insert e.id {} acc) {} entries)
          entries
      in

      # --- tags -------------------------------------------------------------
      #
      # The registry (`law.tag_registry`) is the key SET for by_tag/by_direction
      # and the pair universe for co_occurrence — never the corpus's own tags,
      # which would silently drop a registered-but-unused tag from the index
      # (exactly the "confidently incomplete" failure the extractor's own
      # findings mechanism exists to avoid, here applied to a query view).
      let tag_registry = law.tag_registry in
      let tag_names = std.record.fields tag_registry in
      let tags_of = fun e => get_or "tags" [] e in
      let has_tag = fun t e => std.array.any (fun x => x == t) (tags_of e) in
      let entries_with_tag = fun t =>
        entries |> std.array.filter (has_tag t) |> std.array.map (fun e => e.id)
      in
      let is_direction_tag = fun t => tag_registry."%{t}".category == "direction" in
      let direction_tags = tag_names |> std.array.filter is_direction_tag in
      let tag_index = fun names =>
        std.array.fold_left
          (fun acc t => std.record.insert t (entries_with_tag t) acc)
          {}
          names
      in
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
            { id = e.id, floors = std.record.fields floors_of."%{e.id}" }),
        by_tag = tag_index tag_names,
        by_direction = tag_index direction_tags,
        co_occurrence =
          std.array.fold_left
            (fun acc a =>
              std.array.fold_left
                (fun acc2 b =>
                  if std.string.compare a b == 'Lesser then
                    std.record.insert "%{a}+%{b}"
                      (entries
                       |> std.array.filter (fun e => has_tag a e && has_tag b e)
                       |> std.array.map (fun e => e.id))
                      acc2
                  else acc2)
                acc
                tag_names)
            {}
            tag_names,
        untagged =
          entries
          |> std.array.filter (fun e => std.array.length (tags_of e) == 0)
          |> std.array.map (fun e => e.id),
      },
  }
)
