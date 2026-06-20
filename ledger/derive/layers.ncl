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
let dag = import "../fixtures/dag_valid.ncl" in
let nodes = dag.nodes in
let n_count = std.array.length nodes in

# ids whose deps are all contained in `settled`, excluding those already settled
let ready = fun settled =>
  std.array.filter
    (fun n =>
      !(std.array.elem n.id settled)
      && std.array.all (fun d => std.array.elem d settled) n.depends_on)
    nodes
  |> std.array.map (fun n => n.id)
in

# build layers: each round takes the currently-ready ids as the next layer and
# adds them to the settled set; bounded by |nodes| rounds (a valid DAG settles in
# at most that many). Empty layers (none ready) are dropped.
let step = fun acc _i =>
  let settled = std.array.flatten acc.layers in
  let next = ready settled in
  if std.array.length next == 0
  then acc
  else { layers = acc.layers @ [next] }
in
let built =
  std.array.fold_left
    step
    { layers = [] }
    (std.array.generate (fun i => i) n_count)
in
{
  layer_count = std.array.length built.layers,
  layers = built.layers,
}
