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
{
  Dag = std.contract.custom (fun _label value =>
    let nodes = value.nodes in
    let ids = std.array.map (fun n => n.id) nodes in
    # referential integrity: every depends_on resolves to a declared node id
    let all_edges_resolve =
      std.array.all
        (fun n => std.array.all (fun d => std.array.elem d ids) n.depends_on)
        nodes
    in
    # acyclicity via Kahn reduction: settle nodes whose deps are all settled,
    # iterating |nodes| rounds. If any node is unsettled afterward, a cycle exists.
    let settle_round = fun settled =>
      std.array.fold_left
        (fun acc n =>
          if std.array.elem n.id acc then acc
          else if std.array.all (fun d => std.array.elem d acc) n.depends_on
          then acc @ [n.id]
          else acc)
        settled
        nodes
    in
    let n_count = std.array.length nodes in
    let final_settled =
      std.array.fold_left
        (fun acc _i => settle_round acc)
        []
        (std.array.generate (fun i => i) n_count)
    in
    let acyclic = std.array.length final_settled == n_count in
    let dedup =
      std.array.fold_left
        (fun acc x => if std.array.elem x acc then acc else acc @ [x])
        []
        ids
    in
    let unique_ids = std.array.length ids == std.array.length dedup in
    if !unique_ids then 'Error { message = "duplicate node id" }
    else if !all_edges_resolve then 'Error { message = "dangling depends_on edge" }
    else if !acyclic then 'Error { message = "cycle detected in DAG" }
    else 'Ok value
  ),

  # Node contract: a node declares the fields the campaign reasons over. The
  # record is open — human-facing fields (title, rationale) and the optional
  # `serialize` marker may ride alongside and are ignored by the contract.
  Node = {
    id | String,
    depends_on | Array String,
    file_surface | Array String,   # paths/globs this node may touch
    discipline | [| 'core, 'refine |],
    mitigates | Array String,      # finding ids this node addresses
  },

  # Conflict-detection gate (C10 part c), layered over `Dag`. Concurrent nodes
  # (no dependency path between them) MUST declare disjoint file_surface OR carry
  # an explicit `serialize` marker.
  DagNoConflict = std.contract.custom (fun _label value =>
    let nodes = value.nodes in
    let find = fun id => std.array.filter (fun n => n.id == id) nodes in
    let deps_of = fun id =>
      let m = find id in
      if std.array.length m == 0 then [] else (std.array.first m).depends_on
    in
    # reachable set from a start id over depends_on, bounded by |nodes| rounds
    let n_count = std.array.length nodes in
    let expand = fun frontier =>
      std.array.fold_left
        (fun acc id =>
          std.array.fold_left
            (fun a2 d => if std.array.elem d a2 then a2 else a2 @ [d])
            acc
            (deps_of id))
        frontier
        frontier
    in
    let reach = fun start =>
      std.array.fold_left
        (fun acc _i => expand acc)
        (deps_of start)
        (std.array.generate (fun i => i) n_count)
    in
    # two nodes are ORDERED if one is in the other's transitive dep closure
    let ordered = fun a b =>
      std.array.elem b.id (reach a.id) || std.array.elem a.id (reach b.id)
    in
    # surfaces overlap if they share any declared path/glob token (exact-string
    # disjointness; the campaign normalizes surfaces to comparable tokens)
    let surfaces_overlap = fun a b =>
      std.array.any (fun s => std.array.elem s b.file_surface) a.file_surface
    in
    let has_serialize = fun n =>
      std.record.has_field "serialize" n && n.serialize == true
    in
    # for every unordered pair, require disjoint surfaces OR a serialize marker
    let pairs_ok =
      std.array.all
        (fun a =>
          std.array.all
            (fun b =>
              if a.id == b.id then true
              else if ordered a b then true
              else if !(surfaces_overlap a b) then true
              else (has_serialize a || has_serialize b))
            nodes)
        nodes
    in
    if !pairs_ok
    then 'Error { message = "concurrent nodes share file_surface without serialize marker" }
    else 'Ok value
  ),
}
