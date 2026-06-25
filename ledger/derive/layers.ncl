# Derived parallel layering (C-P3.4). The execution layers are computed FROM the
# DAG topology by Kahn's algorithm — never hand-authored. Layer 0 is the set of
# nodes with no dependencies; layer k is the set of nodes all of whose deps are
# already settled in layers < k. Nodes within a layer have no path between them,
# so they may run concurrently (subject to the conflict gate in contracts/dag.ncl).
#
# This derivation imports the shipped positive-control fixture DAG, so it only
# ever computes over a graph that already passed `Dag` + `DagNoConflict`.
# `nickel export` of this file emits the layering as JSON; re-running on the
# same DAG reproduces it deterministically (the evaluator for C-P3.4).
# Real campaigns bind their own DAG path — see skills/orchestration/demo/layers.ncl
# for the live-campaign pattern where the import is repointed to the active DAG.
#
# Performance + continuation: the settled set is a RECORD (O(1) `has_field`), not
# an array re-scanned with `std.array.elem` each round; and nodes flagged
# `complete` are PRE-SETTLED — they never appear in the emitted schedule, so a
# continuation derives layers only for the active remainder. (Mirrors the same
# treatment in contracts/dag.ncl.)
let dag = import "../fixtures/dag_valid.ncl" in
let nodes = dag.nodes in
let n_count = std.array.length nodes in

# record-as-set helpers (membership is O(1) `has_field`)
let set_insert = fun id s => if std.record.has_field id s then s else std.record.insert id true s in
let set_of = fun arr => std.array.fold_left (fun acc id => set_insert id acc) {} arr in
let is_complete = fun n => std.record.has_field "complete" n && n.complete == true in

# completed nodes are pre-settled (already landed in a prior layer) and are never
# scheduled again — the derivation covers only the active remainder.
let pre_settled = set_of (std.array.map (fun n => n.id) (std.array.filter is_complete nodes)) in

# ids whose deps are all in the settled SET and not yet settled themselves;
# completed nodes are excluded from the schedule (pre-settled above).
let ready = fun settled =>
  std.array.filter
    (fun n =>
      !(is_complete n)
      && !(std.record.has_field n.id settled)
      && std.array.all (fun d => std.record.has_field d settled) n.depends_on)
    nodes
  |> std.array.map (fun n => n.id)
in

# build layers: each round takes the currently-ready ids as the next layer and
# inserts them into the settled record-set; bounded by |nodes| rounds (a valid DAG
# settles in at most that many). Empty layers (none ready) terminate the build.
let step = fun acc _i =>
  let next = ready acc.settled in
  if std.array.length next == 0
  then acc
  else
    {
      layers = acc.layers @ [next],
      settled = std.array.fold_left (fun s id => set_insert id s) acc.settled next,
    }
in
let built =
  std.array.fold_left
    step
    { layers = [], settled = pre_settled }
    (std.array.generate (fun i => i) n_count)
in
{
  layer_count = std.array.length built.layers,
  layers = built.layers,
}
