# Pure value-transformation core for the anchored-reachability open-surface
# primitive (node/open-surface). ledger/derive/anchored_surface.sh owns CLI
# parsing, extraction (extract_entries.py), the entry_apply.ncl validation
# gate, and budget-bounded rendering/truncation; this file owns everything
# that is graph computation over an already-validated corpus: the undirected
# two-hop reachability walk, the open-surface membership filter, per-ranker
# ordering, and the backed-exclusion count.
#
# This file previously also computed a ranker "recall" number over
# reachability. It is CUT (ruling-holdout-fate.md [HV4]): the label named
# ordering quality, which is only decidable against relevance ground truth,
# and no corpus in this system carries relevance labels — every label-free
# construction of it degenerates, either into a self-consistency check or
# into a restatement of the two-hop walk this file already performs and the
# suite already binds directly. The backed-exclusion count below is the
# half of the old split that measured a real, corpus-side property and
# needed no labels to do it ([HV5]).
#
# Input shape:
#   { entries = [Entry, ..], directives = [Directive, ..] | optional,
#     anchors = [String, ..], ranker = String }
# `entries` and `directives` are the validated export's own fields —
# untouched, not re-shaped. `directives` mirrors entry.ncl's own optional-
# field idiom (a corpus predating directives, or a caller that strips them,
# carries no such field) and defaults to `[]` below.
#
# DIRECTIVES TRANSIT THE WALK BUT NEVER SURFACE IN ITS OUTPUT. A directive
# closes by authority, not evidence (docs/entries.md's own grade vocabulary),
# so it carries no backing/closure state on the axis `is_member` measures —
# admitting it as a candidate would misrepresent a standing rule as an
# unresolved evidentiary claim. The architect's own measurement of this
# view ([A4] in ruling-hooks-boundary.md) scopes the emitted text to
# "questions and unclosed claims" — directives are excluded from that scope
# by the ruling itself, not by an omission this file introduces. What the
# ruling does NOT exempt them from is the GRAPH: `[A4]`'s check runs "two
# edges over the declared provenance and closure graph", and a directive is
# a first-class node of that graph — reachable as an anchor, and as a
# two-hop bridge between two entries that each cite it.
#
# Reuse, not redefinition (ruling-hooks-boundary.md's no-second-definition
# rule; ruling-open-surface-node.md U4/U6). `law.corpus_edges_of` and
# `law.refs_of` are entry.ncl's own EXPORTED primitives and are used exactly
# as entries_query.ncl uses them. `is_open` itself is now IMPORTED, not
# reimplemented: entries_query.ncl was restructured to follow entry.ncl's own
# named-field pattern (a record with doc-stringed fields, the `Views`
# contract among them, rather than a bare contract at the top level — see
# entries_query.ncl's own header), so `query.is_open` is the SAME closed-id-
# set composition over `law.refs_of "discharges"/"supersedes"` entries_query.ncl's
# `Views` uses internally, applied to this file's own `entries`. The gap this
# comment used to name — the closed-id-set logic here was a byte-identical
# copy because nothing in entries_query.ncl could be imported — is closed;
# the two were verified behaviorally equivalent over the live corpus (2462
# entries, 0 mismatches) before this file stopped carrying its own copy.
let law = import "../contracts/entry.ncl" in
let query = import "../contracts/entries_query.ncl" in

# record-as-set idiom (shared with entries_query.ncl / dag.ncl / layers.ncl):
# O(1) membership via std.record.has_field rather than an array scan.
let set_insert = fun id s => if std.record.has_field id s then s else std.record.insert id true s in

fun input =>
  let entries = input.entries in
  let directives =
    if std.record.has_field "directives" input then input.directives else []
  in
  let directive_id_set =
    std.array.fold_left (fun acc d => set_insert d.id acc) {} directives
  in
  let id_map = std.array.fold_left (fun acc e => std.record.insert e.id e acc) {} entries in
  let is_claim = fun e => law.matches e.assertion 'claim "claim" in

  # --- openness (IMPORTED, see file header) ---------------------------------
  let is_open = query.is_open entries in

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
  # traversal"). A provenance edge (because/depends, via law.corpus_edges_of
  # — the walkable subset; an external `because` ref has no corpus node to
  # walk to) and a closure edge (discharges/supersedes) are both authored
  # as directed refs on the entry that names them, but the reach-note
  # fixture's own golden
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
  # `entries @ directives`, not `entries` alone: a directive is a first-class
  # node of the walk (see the header comment), and folding it in here — same
  # `refs_of`-guarded helpers, same shape — is what lets an anchor land on a
  # directive id and lets a directive bridge two entries that each cite it.
  # `law.refs_of` is guarded (`[]` when the field is absent), so a directive
  # object (id + statement, no depends/because/discharges/supersedes today —
  # entry.ncl's own comment on why they close by authority, not derivation)
  # contributes no OUTGOING edge of its own; it still becomes an adjacency
  # key via the INCOMING half `add_undirected` adds for every entry that
  # cites it, which is what makes it reachable at all.
  let graph_nodes = entries @ directives in
  let directed_pairs =
    std.array.fold_left
      (fun acc e =>
        let outs = (law.corpus_edges_of e) @ (law.refs_of "discharges" e) @ (law.refs_of "supersedes" e) in
        acc @ (std.array.map (fun r => { from = e.id, to = r }) outs))
      []
      graph_nodes
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
  # diverge — the same hazard `eligible_pairs`/`excluded_backed` sidestep
  # further down.
  let ranked_candidates = std.array.sort cmp reachable_members in

  # --- the backed-exclusion count -------------------------------------------
  #
  # Every WALKABLE derivation edge (law.corpus_edges_of: depends + because's
  # corpus-tagged refs) in the corpus is one pair, deriving entry -> its
  # named target — the provenance gate
  # already forces every unclosed claim to carry at least one, so this scans
  # the whole corpus rather than a hand-picked subset. A pair's target is
  # excluded when it fails open-surface membership by being backed
  # (corroborated/vouched, `is_member` above) — a property of the CORPUS,
  # decidable without a graph walk, and true regardless of anchor, ranker,
  # or budget: a backed target can never surface no matter how it is
  # reached. Folded over `graph_nodes` (entries @ directives, see above) for
  # the same future-proofing reason as `directed_pairs`, though a directive
  # contributes none today: `law.corpus_edges_of` on one yields `[]`.
  let derivation_pairs =
    std.array.fold_left
      (fun acc e => acc @ (std.array.map (fun r => { from = e.id, to = r }) (law.corpus_edges_of e)))
      []
      graph_nodes
  in
  # A pair whose TARGET is a directive is neither backed nor unbacked — a
  # directive carries no evidentiary state at all (it closes by authority),
  # so counting it toward this metric's "backed" numerator would misreport
  # WHY it can never surface. `id_map` (entries only) already reflects that:
  # without this filter such a pair falls through `eligible`'s has_field
  # guard as "not found" and is silently folded into `count` alongside
  # genuinely backed targets — a real corpus's own `because -> directive`
  # citations already produce this miscount today. Scoping `derivation_pairs`
  # to entry-typed targets before `eligible` keeps this metric measuring
  # exactly what its own name and doc comment claim: the backed axis, and
  # nothing a directive citation has any bearing on.
  let entry_targeted_pairs =
    std.array.filter (fun pr => !(std.record.has_field pr.to directive_id_set)) derivation_pairs
  in
  let eligible = fun pr => std.record.has_field pr.to id_map && is_member (id_map."%{pr.to}") in
  let eligible_pairs = std.array.filter eligible entry_targeted_pairs in

  {
    candidates = ranked_candidates,
    excluded_backed = {
      count = std.array.length entry_targeted_pairs - std.array.length eligible_pairs,
      total = std.array.length entry_targeted_pairs,
    },
  }
