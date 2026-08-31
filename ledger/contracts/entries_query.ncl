# The first queries over the typed-claim record — a Nickel evaluation over
# the extractor's export, invoked as a value-transforming contract via the
# `Views` field this file exports:
#
#   nickel export <export>.yaml --apply-contract ledger/contracts/entries_query_apply.ncl
#
# THIS FILE IS THE LAW, entry.ncl's own pattern (see that file's header): named
# fields with doc strings, not a bare contract. `is_open` and the other
# corpus-derived helpers below are therefore reachable to an importer —
# ledger/derive/anchored_surface_core.ncl is the consumer that needed exactly
# this and, before this fix, carried its own duplicate `is_open` because
# nothing here could be imported. `entries_query_apply.ncl` re-exports the
# `Views` field as the bare contract `--apply-contract` requires, mirroring
# the entry.ncl / entry_apply.ncl split already used throughout
# ledger/contracts/.
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
#   dependents_of  — the DUAL of chain_floor: where chain_floor follows a
#                    claim's derivation edges DOWN to where support bottoms
#                    out, dependents_of follows the SAME edges UP, from a
#                    claim to every entry that transitively rests on it —
#                    the missing direction the theory motivating this view
#                    names directly: a claim found false has no way, today,
#                    to enumerate what was built on it. Every other view
#                    here runs downward; this is the first that does not.
#
#                    EDGE CHOICE: both `depends` and `because`'s
#                    corpus-tagged refs reverse — i.e. the exact edge set
#                    `corpus_edges_of` already names, the same graph
#                    chain_floor walks forward. `depends`'s documented
#                    consequence ("this entry breaks" if the target is
#                    deleted, entry.ncl) is the more literal fit for a name
#                    like "dependents", and it was the first edge
#                    considered alone. It was rejected as the SOLE edge for
#                    two convergent reasons: structurally, `corpus_edges_of`
#                    already treats `depends` and because-corpus refs as one
#                    graph for the downward walk, and reversing only half of
#                    that graph would make chain_floor and dependents_of two
#                    different relations wearing a shared name rather than
#                    duals of one; empirically, the live corpus was measured
#                    at this commit to carry ZERO `depends` edges anywhere
#                    (`depends::` has never been authored in `.ledger` — the
#                    extractor's ledger-dialect grammar does not even emit
#                    it, per test_entries_extract.sh's own note on the
#                    point), so a depends-only reverse would be correct and
#                    permanently EMPTY against every real query — unable to
#                    do the one thing this view exists to do. `because` is
#                    weaker in its forward consequence (an orphaned STATED
#                    REASON, not entry breakage) but it is how the corpus
#                    actually records derivation: a `synthesis` claim is
#                    obliged to name at least one antecedent through it
#                    (docs/entries.md), so "what cites this claim as its
#                    reason" is precisely "what needs re-review if the claim
#                    is wrong" — the repair-selection question this view
#                    answers. `because`'s external half stays excluded
#                    exactly as it is forward: `corpus_edges_of` already
#                    filters to corpus-tagged refs only, so reusing it
#                    verbatim costs nothing extra and an external referent
#                    still has no corpus node for either direction to land
#                    on.
#
#                    CYCLES: guarded the same way `chain_floor`'s `walk`
#                    guards them — a `visiting` set per traversal branch, so
#                    a cycle member reached while already on the current
#                    walk's stack contributes nothing FROM THAT EDGE (and
#                    still contributes normally if reached by a separate,
#                    non-cyclic path). EntryStore proves no such acyclicity
#                    for depends/because (only `supersedes` is checked to
#                    terminate), so the same guard chain_floor needs going
#                    down is needed going up.
#
#                    PERFORMANCE: one reverse-adjacency map built once, O(E)
#                    over the corpus (`depended_by`, the `by_id` idiom
#                    inverted), then a PER-CLAIM bounded DFS over it — the
#                    same shape chain_floor settled on after its own
#                    round-based whole-corpus fixed point exhausted memory
#                    at scale (see chain_floor's `walk` comment above). No
#                    cross-claim memoization is added on top: chain_floor's
#                    own fix was replacing the round-based GLOBAL record
#                    with independent per-claim walks, not making the
#                    per-claim walk itself cheaper, so this reuses that
#                    exact trade rather than inventing a second one.
#
#   refutations    — one row per `refutes` edge: {refutation, target, species}.
#                    The SPECIES ("born-false" / "became-false" /
#                    "unclassifiable-refutation") is DERIVED, never
#                    authored — mirroring `is_open` above — from
#                    anchor-comparison (the refuting entry's own check/
#                    witness anchor against the target's) and the target's
#                    axes (architect ruling .ledger/deposits/expiry-
#                    mechanics/architect-seat/2026-08-24-ruling-expiry-
#                    mechanics.md; .ledger/log/2026-08-24-refutation-is-
#                    one-anchored-edge.md RF3/RF4). A target with no anchor
#                    of its own is `unclassifiable-refutation`, never
#                    guessed. GIT ANCESTRY of a non-equal anchor pair is
#                    NOT decided here — this file has no repository access
#                    — so the "became-false" branch trusts the corpus's own
#                    append-only rail; ledger/gate/currency.py is the tool
#                    that verifies that trust against the real repository
#                    and reports `anchor-not-an-ancestor` when it does not
#                    hold.
#
#   impeachment_queue — the born-false-on-CLOSED collision the `impeachment`
#                    theorem names: a snapshot-sound closure and a true
#                    refutation at the same anchor are jointly impossible,
#                    so the model proves the pair contradictory and cannot
#                    itself say which party lied. Every row here is a
#                    `refutations` row whose target is `corroborated` or
#                    `vouched` and whose species is `born-false` — routed to
#                    a human closer, NEVER auto-resolved by this view or any
#                    other.
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

{
  # set-union: fold refs into an id-set record (the id_set idiom this
  # corpus's contracts share throughout) — O(1) membership via
  # std.record.has_field. Exported alongside `is_open` because both of
  # `is_open`'s two production consumers (this file's own `Views` below, and
  # ledger/derive/anchored_surface_core.ncl) build the SAME closed-id-set
  # shape with it.
  add_all
    | doc "fold an array of ids into an existing id-set record; O(1) membership"
    = fun acc refs =>
      std.array.fold_left
        (fun a r => if std.record.has_field r a then a else std.record.insert r true a)
        acc
        refs,

  # openness, DERIVED, never authored (see the file header's OPENNESS
  # paragraph): an entry is open iff no entry in the corpus names it in a
  # `discharges` or `supersedes` edge. Curried on the corpus's `entries` so
  # the O(E) closed-id-set fold runs ONCE per corpus rather than once per
  # predicate call — `is_open entries` builds the set and returns the
  # per-entry test, the same shape this file's own `Views` below and
  # ledger/derive/anchored_surface_core.ncl both need. Behavior UNCHANGED
  # from before this field existed: this was a LOCAL binding inside `Views`'
  # contract body, unreachable to any importer, which is why
  # anchored_surface_core.ncl carried an identical copy rather than one.
  is_open
    | doc "fun entries => fun entry => Bool -- an entry is open iff no entry in `entries` names it in a discharges or supersedes edge"
    = fun entries =>
      let closed_ids =
        std.array.fold_left
          (fun acc e =>
            add_all acc (law.refs_of "discharges" e @ law.refs_of "supersedes" e))
          {}
          entries
      in
      fun e => !(std.record.has_field e.id closed_ids),

  # the value-transforming --apply-contract entry point over a validated
  # typed-claim corpus export. entries_query_apply.ncl re-exports this field
  # as the bare contract `nickel export --apply-contract` requires.
  Views
    | doc "the corpus query contract: validates via entry_apply.ncl, then computes the exported views"
    = std.contract.custom (fun label value =>
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

      # --- openness (the exported `is_open` field above, applied to this
      # corpus's own `entries` -- NOT redefined here; see that field's doc
      # string for why the closed-id-set fold is curried) -----------------
      let is_open = is_open entries in

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

      # --- dependents (upward) ---------------------------------------------
      #
      # The reverse of chain_floor's graph, over the identical edge set
      # (`corpus_edges_of` — see the header comment's EDGE CHOICE section
      # for why `depends` alone was rejected). `depended_by` is the one
      # reverse-adjacency build, O(edges): for every entry, invert each of
      # its corpus-walkable edges into the map, target -> [citing ids].
      let depended_by =
        std.array.fold_left
          (fun acc e =>
            std.array.fold_left
              (fun a target =>
                let cur = if std.record.has_field target a then a."%{target}" else [] in
                std.record.update target (cur @ [e.id]) a)
              acc
              (law.corpus_edges_of e))
          {}
          entries
      in
      # PER-CLAIM bounded DFS over `depended_by`, `visiting`-guarded exactly
      # like `walk` above: a cycle member already on the current branch's
      # stack contributes nothing from that edge, and a separate,
      # non-cyclic path to the same id still contributes normally. Unlike
      # `walk`, whose answer is a category label rather than a set of ids,
      # this walk's answer IS the set of ids reached — so the "contributes
      # nothing" rule has to be enforced at the point an id is ADDED to the
      # result, not only at the point recursion would re-enter it (see the
      # guard inside the fold below).
      let rec dependents_walk = fun visiting id =>
        if std.record.has_field id visiting then
          {}
        else
          let visiting_here = std.record.insert id true visiting in
          let direct =
            if std.record.has_field id depended_by then depended_by."%{id}" else []
          in
          std.array.fold_left
            (fun acc dep_id =>
              # `dep_id` closing a cycle back onto the CURRENT branch (the
              # root or any ancestor already on the stack) contributes
              # nothing from this edge — not just "do not recurse further",
              # but "do not record dep_id as newly reached either": adding
              # it unconditionally here would let a pure cycle (dep:F <->
              # dep:G, neither edge supplying anything from outside) report
              # each claim as its own transitive dependent, which is not a
              # real answer to "what rests on this claim" — it rests on
              # itself only in the trivial, unhelpful sense every element of
              # a cycle does.
              if std.record.has_field dep_id visiting_here then
                acc
              else
                add_all
                  (add_all acc [dep_id])
                  (std.record.fields (dependents_walk visiting_here dep_id)))
            {}
            direct
      in

      # --- refutations (the falsity edge, species DERIVED) -----------------
      #
      # RF4/[R1]/[AD1]: one anchored edge, two derived verdicts, zero
      # authored labels — the SAME derived-never-authored rule `is_open`
      # already applies to closure. `anchor_of` reads the anchor Check/
      # Witness already carry (RefutesAnchored, entry.ncl, guarantees a
      # REFUTING entry always has one; a TARGET may not).
      let anchor_of = fun e =>
        if std.record.has_field "check" e then e.check.at
        else if std.record.has_field "witness" e then e.witness.at
        else null
      in
      # Species, per RF3/RF4/monotone_refutation_is_born_false:
      #   - target unanchored                       -> unclassifiable-refutation
      #   - target's own axes are +monotone          -> born-false, ALWAYS
      #     (a monotone claim once true stays true, so a later-anchored
      #     refutation convicts the claim's own birth anchor, mechanically —
      #     no anchor comparison needed for this branch)
      #   - refutation.anchor == target.anchor       -> born-false
      #   - otherwise                                -> became-false
      #     (git ANCESTRY of a non-equal anchor pair is not decidable inside
      #     Nickel — no repository access here — so this branch assumes the
      #     append-only ordering the corpus's own never-rewrite rail
      #     maintains, per H1/[LM3]/[LM6]; ledger/gate/currency.py is the
      #     tool that verifies that ordering against the real repository,
      #     including the `anchor-not-an-ancestor` report when it does not
      #     hold — a git-level precondition this pure-value derivation
      #     cannot itself check.)
      let refutation_species = fun refuting_anchor target =>
        let target_anchor = anchor_of target in
        if target_anchor == null then
          "unclassifiable-refutation"
        else if std.record.has_field "axes" target && target.axes.monotone then
          "born-false"
        else if refuting_anchor == target_anchor then
          "born-false"
        else
          "became-false"
      in
      let refuting_entries =
        std.array.filter (fun e => std.array.length (law.refs_of "refutes" e) > 0) entries
      in
      let refutation_rows =
        std.array.fold_left
          (fun acc e =>
            let refuting_anchor = anchor_of e in
            acc
            @ (law.refs_of "refutes" e
               |> std.array.map (fun tid =>
                 if !(std.record.has_field tid by_id) then
                   # EntryStore already refuses a dangling `refutes` at the
                   # corpus granularity; this branch only guards a query run
                   # over a lone, unvalidated entry export.
                   { refutation = e.id, target = tid, species = "unclassifiable-refutation" }
                 else
                   { refutation = e.id, target = tid,
                     species = refutation_species refuting_anchor by_id."%{tid}" })))
          []
          refuting_entries
      in
      # Impeachment queue: the born-false-on-CLOSED collision RF3/RF4/the
      # `impeachment` theorem name — a snapshot-sound closure and a true
      # refutation at the same anchor are jointly impossible, so the model
      # proves the pair contradictory and cannot itself name which party
      # lied. Routed to a human closer, NEVER auto-resolved: this view is a
      # derived READ of the collision, not a resolution of it.
      let impeachment_rows =
        std.array.filter
          (fun row =>
            row.species == "born-false"
            && std.record.has_field row.target by_id
            && is_closed_evidence (by_id."%{row.target}"))
          refutation_rows
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
        dependents_of =
          entries
          |> std.array.filter is_claim
          |> std.array.map (fun e =>
            { id = e.id, dependents = std.record.fields (dependents_walk {} e.id) }),
        refutations = refutation_rows,
        impeachment_queue = impeachment_rows,
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
    ),
}
