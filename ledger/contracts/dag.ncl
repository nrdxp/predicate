# Campaign DAG contracts (C10). Two intrinsic contracts, composed in order:
#
#   value | Dag | DagNoConflict
#
# `Dag` makes acyclicity + referential integrity + id-uniqueness INTRINSIC.
# `DagNoConflict` makes the concurrent-surface conflict check INTRINSIC too.
# A broken graph (cycle, dangling edge, duplicate id, or an undeclared
# concurrent-surface conflict) makes `nickel export` exit non-zero — so the
# single command `nickel export` IS the gate, with no JSON-roundtrip step a
# headless orchestrator could skip.
#
# Locus decision: the conflict check is a SECOND intrinsic contract composed
# after `Dag`, rather than a companion validator over exported JSON. Rationale:
# keeping it intrinsic means `nickel export` is the one portable gate; there is
# no out-of-band step to forget. Acyclicity and referential integrity remain
# intrinsic in `Dag` as required.
#
# Performance: every set/map below is a RECORD — membership is O(1) `has_field`,
# lookup is O(1) `"%{id}"` — never an array with a linear `std.array.elem`/`find`
# scan. `DagNoConflict` MEMOIZES each node's reachable set once (`reach_map`)
# instead of recomputing the transitive closure twice per pair inside the O(n^2)
# loop. The earlier array-based version was ~O(n^5) with a large constant; this is
# ~O(n^2) over O(1) record operations (the campaign's own 30-node DAG dropped from
# minutes to sub-second).
#
# Shared definitions (D-DUP / T1.1): the `discipline` enum and the surface-
# containment predicate both have ONE canonical home, imported rather than
# inlined, so they cannot drift from the IBC contract or from authorized.py:
#   discipline.ncl  the 5-value worker-discipline enum (shared with worker_ibc.ncl)
#   authorized.ncl  tokens_overlap / token_contains (shared with authorized.py)
let disciplines = import "discipline.ncl" in
let auth = import "authorized.ncl" in
{
  # Node contract: a node declares the fields the campaign reasons over. The
  # record is open — human-facing fields (title, rationale) and the optional
  # `serialize` marker may ride alongside and are ignored by the contract.
  #
  # `discipline` enumerates the surviving worker workflows: 'core (feature/TDD),
  # 'refine (polish), 'doc (documentation), 'form (formal domain modeling),
  # and 'spec (normative specification) — defined ONCE in discipline.ncl and
  # imported here so it cannot drift from worker_ibc.ncl. An out-of-enum tag
  # fails the contract — but ONLY because `Dag` applies this contract per element
  # (below); a defined-but-unapplied contract enforces nothing.
  Node = {
    id | String,
    depends_on | Array String,
    file_surface | Array String,   # paths/globs this node may touch
    discipline | disciplines.Discipline,
    mitigates | Array String,      # finding ids this node addresses
    ..                             # open: title/rationale/serialize ride along
  },

  # --- record-as-set helpers ----------------------------------------------------
  # A SET is a record `{ "<id>" = true }`; membership is O(1) `has_field`. Inserts
  # are dup-tolerant (raw `std.record.insert` raises on an existing field), so
  # id-uniqueness is decided by comparing cardinalities, never by a crash.
  set_insert | doc "add an id to a record-set, tolerant of repeats"
    = fun id s => if std.record.has_field id s then s else std.record.insert id true s,
  set_of | doc "build a record-set from an array of ids"
    = fun arr => std.array.fold_left (fun acc id => set_insert id acc) {} arr,
  set_size | doc "cardinality of a record-set"
    = fun s => std.array.length (std.record.fields s),
  # `complete = true` marks a node already landed + validated in a prior layer.
  # Such nodes are pre-settled for acyclicity and EXCLUDED from the active
  # conflict/reach work — a continuation pays only for the incomplete remainder,
  # not the whole accumulated graph. (Referential integrity + node conformance
  # still cover ALL nodes; a completed node remains a valid dep target.)
  is_complete | doc "node already landed in a prior layer (excluded from active work)"
    = fun n => std.record.has_field "complete" n && n.complete == true,

  Dag = std.contract.custom (fun _label value =>
    let nodes = value.nodes in
    # Per-element node conformance: annotate each node with the `Node` contract
    # so the field shapes and the `discipline` enum are actually enforced. A
    # contract defined but never applied is inert; checking it over each element
    # is what makes `discipline | disciplines.Discipline` a real gate. The
    # annotation form `(n | Node)` under `std.deep_seq` raises the violation
    # EAGERLY — `std.contract.apply` alone stays lazy and the bad node slips
    # through `nickel export`. deep_seq descends into the annotated fields so an
    # out-of-enum discipline fails the export rather than being skipped.
    let _node_conformance =
      std.array.fold_left
        (fun acc n => std.deep_seq (n | Node) acc)
        null
        nodes
    in
    let ids = std.array.map (fun n => n.id) nodes in
    # id set (record) — O(1) membership; cardinality decides id-uniqueness.
    let id_set = set_of ids in
    let unique_ids = std.array.length ids == set_size id_set in
    # referential integrity: every depends_on resolves to a declared node id (O(1))
    let all_edges_resolve =
      std.array.all
        (fun n => std.array.all (fun d => std.record.has_field d id_set) n.depends_on)
        nodes
    in
    # acyclicity via Kahn reduction over a record-set of settled ids. Each round
    # settles EVERY node whose deps are all settled (O(1) lookups); a DAG settles
    # all nodes within |nodes| rounds, a cycle leaves some node forever unsettled.
    let n_count = std.array.length nodes in
    let settle_round = fun settled =>
      std.array.fold_left
        (fun acc n =>
          if std.record.has_field n.id acc then acc
          else if std.array.all (fun d => std.record.has_field d acc) n.depends_on
          then std.record.insert n.id true acc
          else acc)
        settled
        nodes
    in
    # complete nodes are pre-settled — already landed + validated in a prior
    # layer — so the Kahn only settles the active remainder on top of them.
    let pre_settled = set_of (std.array.map (fun n => n.id) (std.array.filter is_complete nodes)) in
    let final_settled =
      std.array.fold_left
        (fun acc _i => settle_round acc)
        pre_settled
        (std.array.generate (fun i => i) n_count)
    in
    let acyclic = set_size final_settled == n_count in
    # `std.seq _node_conformance` forces the per-element `Node` applications
    # (above) before the structural verdict, so a malformed node fails the
    # contract eagerly rather than being skipped by laziness.
    std.seq _node_conformance (
      if !unique_ids then 'Error { message = "duplicate node id" }
      else if !all_edges_resolve then 'Error { message = "dangling depends_on edge" }
      else if !acyclic then 'Error { message = "cycle detected in DAG" }
      else 'Ok value
    )
  ),

  # Conflict-detection gate (C10 part c), layered over `Dag`. Concurrent nodes
  # (no dependency path between them) MUST declare disjoint file_surface OR carry
  # an explicit `serialize` marker.
  DagNoConflict = std.contract.custom (fun _label value =>
    let nodes = value.nodes in
    let n_count = std.array.length nodes in
    # id -> depends_on map (record), O(1) lookup (was a linear `find` per call).
    let deps_map =
      std.array.fold_left
        (fun acc n => if std.record.has_field n.id acc then acc else std.record.insert n.id n.depends_on acc)
        {}
        nodes
    in
    let deps_get = fun id => if std.record.has_field id deps_map then deps_map."%{id}" else [] in
    # reach(start): transitive depends_on closure as a record-set. Expansion adds
    # each seen id's direct deps; bounded by |nodes| rounds (the closure converges).
    let reach_of = fun start =>
      let expand = fun seen =>
        std.array.fold_left
          (fun acc id =>
            std.array.fold_left (fun a2 d => set_insert d a2) acc (deps_get id))
          seen
          (std.record.fields seen)
      in
      std.array.fold_left
        (fun acc _i => expand acc)
        (set_of (deps_get start))
        (std.array.generate (fun i => i) n_count)
    in
    # complete nodes participate in NO pair (a new node touching a completed
    # node's file is ordered after it by a dep), so reach + pairs run over the
    # ACTIVE set only. Dep traversal still uses the full deps_map, since an active
    # node may depend on a completed one.
    let active = std.array.filter (fun n => !(is_complete n)) nodes in
    # MEMOIZE each active node's reach-set ONCE — the key fix. The old code
    # recomputed `reach` twice for every one of the O(n^2) pairs.
    let reach_map =
      std.array.fold_left
        (fun acc n => if std.record.has_field n.id acc then acc else std.record.insert n.id (reach_of n.id) acc)
        {}
        active
    in
    let reach_get = fun id => if std.record.has_field id reach_map then reach_map."%{id}" else {} in
    # two nodes are ORDERED if one is in the other's transitive dep closure (O(1))
    let ordered = fun a b =>
      std.record.has_field b.id (reach_get a.id) || std.record.has_field a.id (reach_get b.id)
    in
    # Two surface TOKENS overlap when one path-contains the other, not merely when
    # byte-equal. The containment predicate (`tokens_overlap`) is defined ONCE in
    # authorized.ncl and imported here, so this conflict gate and the authorization
    # gate (authorized.py) cannot drift apart (D-DUP). Surfaces overlap if ANY token
    # pair overlaps under path-containment.
    let surfaces_overlap = fun a b =>
      std.array.any
        (fun s1 => std.array.any (fun s2 => auth.tokens_overlap s1 s2) b.file_surface)
        a.file_surface
    in
    let has_serialize = fun n =>
      std.record.has_field "serialize" n && n.serialize == true
    in
    # for every unordered ACTIVE pair, require disjoint surfaces OR a serialize
    # marker. Completed nodes are excluded (already landed; ordered-after by deps).
    let pairs_ok =
      std.array.all
        (fun a =>
          std.array.all
            (fun b =>
              if a.id == b.id then true
              else if ordered a b then true
              else if !(surfaces_overlap a b) then true
              else (has_serialize a || has_serialize b))
            active)
        active
    in
    if !pairs_ok
    then 'Error { message = "concurrent nodes share file_surface without serialize marker" }
    else 'Ok value
  ),
}
