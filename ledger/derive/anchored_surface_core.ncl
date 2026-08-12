# Pure value-transformation core for the anchored-reachability open-surface
# primitive (node/open-surface). ledger/derive/anchored_surface.sh owns CLI
# parsing, extraction (extract_entries.py), the entry_apply.ncl validation
# gate, and budget-bounded rendering/truncation; this file owns everything
# that is graph computation over an already-validated corpus: the undirected
# two-hop reachability walk, the open-surface membership filter, per-ranker
# ordering, and the holdout self-evaluator's two numbers.
#
# Input shape: { entries = [Entry, ..], anchors = [String, ..], ranker = String }
# `entries` is the validated export's own field — untouched, not re-shaped.
#
# Reuse, not redefinition (ruling-hooks-boundary.md's no-second-definition
# rule; ruling-open-surface-node.md U4/U6). `law.edges_of` and
# `law.refs_of` are entry.ncl's own EXPORTED primitives and are used exactly
# as entries_query.ncl uses them. entries_query.ncl's own `is_open` is NOT
# itself an importable binding: that file's only exported value is the bare
# contract its two existing callers apply with `--apply-contract`
# (test_corpus_ids.sh, test_entries_extract.sh), so wrapping a record export
# around it to expose `is_open` as a field would change that contract's
# shape for callers that never asked for one. This file's `closed_ids`/
# `is_open` below is therefore the identical one-line closed-id-set
# composition over `law.refs_of "discharges"/"supersedes"` entries_query.ncl
# already uses — built from the actually-exported primitive, not a second,
# divergent notion of openness. Named in the node's report as a gap between
# what the boundary asked to reuse and what the file structure lets a caller
# reuse.
let law = import "../contracts/entry.ncl" in

# record-as-set idiom (shared with entries_query.ncl / dag.ncl / layers.ncl):
# O(1) membership via std.record.has_field rather than an array scan.
let set_insert = fun id s => if std.record.has_field id s then s else std.record.insert id true s in

fun input =>
  let entries = input.entries in
  let id_map = std.array.fold_left (fun acc e => std.record.insert e.id e acc) {} entries in
  let is_claim = fun e => law.matches e.assertion 'claim "claim" in

  # --- openness (reused composition, see file header) ----------------------
  let add_all = fun acc refs =>
    std.array.fold_left (fun a r => set_insert r a) acc refs
  in
  let closed_ids =
    std.array.fold_left
      (fun acc e => add_all acc (law.refs_of "discharges" e @ law.refs_of "supersedes" e))
      {}
      entries
  in
  let is_open = fun e => !(std.record.has_field e.id closed_ids) in

  # A backed claim (corroborated or vouched) is never a member of the open
  # surface, by construction, regardless of distance or discharge status
  # ([U4], the reach-note fixture's A1, the holdout fixture's D2). Combined
  # with `is_open` this is the full open-surface membership predicate: not
  # backed, and not discharged/superseded by anything else in the corpus.
  let is_backed = fun e =>
    is_claim e
    && (law.matches e.backing 'corroborated "corroborated"
        || law.matches e.backing 'vouched "vouched")
  in
  let is_member = fun e => !(is_backed e) && is_open e in

  # --- the graph the walk traverses: UNDIRECTED, whole-corpus, both edge
  # species at once ([U4] — "the walk traverses the whole graph; the
  # open-surface restriction applies to the output and never to the
  # traversal"). A provenance edge (because/depends, via law.edges_of) and a
  # closure edge (discharges/supersedes) are both authored as directed refs
  # on the entry that names them, but the reach-note fixture's own golden
  # (A1 -[discharges]-> Q1 -[because]-> H1, walked start to finish to place
  # H1 two hops from A1) requires walking either direction of either kind —
  # so both are folded into one undirected adjacency, never filtered by
  # openness before the walk runs.
  # `std.record.update` (not `.insert`, which ERRORS on an already-present
  # field — the id most edges revisit) both creates and overwrites, so it is
  # the one call this accumulator needs regardless of whether `a` has been
  # seen before.
  let add_edge = fun adj a b =>
    let cur = if std.record.has_field a adj then adj."%{a}" else [] in
    std.record.update a (cur @ [b]) adj
  in
  let add_undirected = fun adj pair => add_edge (add_edge adj pair.from pair.to) pair.to pair.from in
  let directed_pairs =
    std.array.fold_left
      (fun acc e =>
        let outs = (law.edges_of e) @ (law.refs_of "discharges" e) @ (law.refs_of "supersedes" e) in
        acc @ (std.array.map (fun r => { from = e.id, to = r }) outs))
      []
      entries
  in
  let adj = std.array.fold_left add_undirected {} directed_pairs in
  let neighbors_of = fun id => if std.record.has_field id adj then adj."%{id}" else [] in

  # Two-hop BFS from one anchor, returning id -> distance (0, 1, or 2). The
  # anchor is distance 0 and is included even when it fails `is_member`
  # (A1's own case): the walk needs to start SOMEWHERE, and the exclusion is
  # applied only once the set is filtered below, never here.
  let bfs2 = fun anchor =>
    let d0 = { "%{anchor}" = 0 } in
    let n1 = neighbors_of anchor in
    let d1 =
      std.array.fold_left
        (fun acc id => if std.record.has_field id acc then acc else std.record.insert id 1 acc)
        d0
        n1
    in
    let n2 = std.array.flatten (std.array.map neighbors_of n1) in
    std.array.fold_left
      (fun acc id => if std.record.has_field id acc then acc else std.record.insert id 2 acc)
      d1
      n2
  in

  # No anchor names the whole corpus as reachable at a shared, constant
  # distance ([A6]/[C4 in ruling-hooks-boundary] "no anchor falls back to
  # recency, never to nothing") — every candidate ties on distance, so the
  # anchored ranker's comparator falls through to its recency tie-break
  # below by construction, with no separate branch needed for "no anchor".
  let reach_dist =
    if std.array.length input.anchors == 0 then
      std.array.fold_left (fun acc e => std.record.insert e.id 0 acc) {} entries
    else
      std.array.fold_left
        (fun acc anchor =>
          let d = bfs2 anchor in
          std.array.fold_left
            (fun a id =>
              let nd = d."%{id}" in
              if std.record.has_field id a then
                (if nd < a."%{id}" then std.record.update id nd a else a)
              else std.record.insert id nd a)
            acc
            (std.record.fields d))
        {}
        input.anchors
  in

  let reachable_members =
    entries
    |> std.array.filter (fun e => std.record.has_field e.id reach_dist && is_member e)
    |> std.array.map (fun e => { id = e.id, statement = e.statement, distance = reach_dist."%{e.id}" })
  in

  # --- ranking ---------------------------------------------------------------
  #
  # `date_key` reads the corpus's own `.ledger/log/` naming convention
  # (`YYYY-MM-DD-topic.md`, extract_entries.py's own comment on its ref
  # regex) straight off the id's document stem — no separate date field
  # exists on Entry to carry it. A stem that does not lead with a date (every
  # fixture but the recency pair) sorts last under descending order, which is
  # exactly "no opinion, rather than a fabricated one."
  let date_key = fun id =>
    let stem = std.array.first (std.string.split ":" id) in
    if std.string.is_match "^[0-9]{4}-[0-9]{2}-[0-9]{2}" stem
    then std.string.substring 0 10 stem
    else ""
  in
  # Nickel's `<`/`>` are Number-only (no string ordering), so the enum comes
  # straight from `std.string.compare` — arguments SWAPPED for the date key
  # (`compare kb ka`) to turn its natural ascending sense into the descending
  # "newest first" this ranker needs, without a separate reversal step.
  let cmp_recency = fun a b =>
    let by_date = std.string.compare (date_key b.id) (date_key a.id) in
    if by_date != 'Equal then by_date else std.string.compare a.id b.id
  in
  # `anchored` ranks closer-to-the-anchor first and falls through to recency
  # to break ties — including the universal tie the no-anchor case manufactures
  # above, which is what makes that case read as plain recency ordering
  # without a second ranker implementation.
  let cmp_anchored = fun a b =>
    if a.distance < b.distance then 'Lesser
    else if a.distance > b.distance then 'Greater
    else cmp_recency a b
  in
  let cmp = if input.ranker == "recency" then cmp_recency else cmp_anchored in
  # Named distinctly from the output field below it: a Nickel record is
  # recursively scoped, so a field literally named `candidates` initialized
  # from an outer `candidates` binding would shadow it with itself and
  # diverge — the same hazard `hit_pairs`/`recall` sidestep further down.
  let ranked_candidates = std.array.sort cmp reachable_members in

  # --- the holdout self-evaluator ---------------------------------------------
  #
  # Every derivation edge (law.edges_of: because + depends) in the corpus is
  # one pair, deriving entry -> its named target — the provenance gate
  # already forces every unclosed claim to carry at least one, so this scans
  # the whole corpus rather than a hand-picked subset ([the holdout fixture's
  # own header]). Recall is measured over reachability ALONE, never over a
  # budget or a ranker's truncation ([U6]: "recall over the set reachable IN
  # PRINCIPLE, which is the ranker's score") — a direct derivation edge is
  # always exactly one hop, always inside the two-hop bound, so this is a
  # structural guarantee the walk must uphold rather than a number that
  # varies with `--budget`/`--ranker`.
  let derivation_pairs =
    std.array.fold_left
      (fun acc e => acc @ (std.array.map (fun r => { from = e.id, to = r }) (law.edges_of e)))
      []
      entries
  in
  let eligible = fun pr => std.record.has_field pr.to id_map && is_member (id_map."%{pr.to}") in
  let eligible_pairs = std.array.filter eligible derivation_pairs in
  let is_hit = fun pr => std.record.has_field pr.to (bfs2 pr.from) in
  let hit_pairs = std.array.filter is_hit eligible_pairs in

  # Field names below are deliberately NOT the same identifiers as the `let`
  # bindings feeding them: a Nickel record is recursively scoped, so a field
  # named `hits` initialized from an outer `hits` binding would shadow it
  # with itself and diverge (`infinite recursion`) rather than read the outer
  # value — the counts are computed above under their own names for exactly
  # this reason.
  {
    candidates = ranked_candidates,
    holdout = {
      recall = {
        hits = std.array.length hit_pairs,
        total = std.array.length eligible_pairs,
      },
      ineligible = {
        count = std.array.length derivation_pairs - std.array.length eligible_pairs,
        total = std.array.length derivation_pairs,
      },
    },
  }
