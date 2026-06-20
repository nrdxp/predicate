# Demonstration DAG for the orchestration driver (the C13-2 / AC5 example test).
# A reviewer exports this, then exports the layering, to reproduce the schedule.
#
#   nix run nixpkgs#nickel -- export skills/orchestration/demo/dag.ncl     # rc 0
#   nix run nixpkgs#nickel -- export skills/orchestration/demo/layers.ncl  # the schedule
#
# Topology: 2 layers.
#   L1 = [D1]                     (foundation)
#   L2 = [D2, D3, D4]
#     D2, D3  conflict-free PARALLEL pair  (disjoint file_surface)
#     D4      SERIALIZE node (serialize=true; shares D2's surface, runs serially)
let c = import "../../../ledger/contracts/dag.ncl" in
(
  {
    nodes = [
      { id = "D1", title = "foundation", depends_on = [],
        file_surface = ["demo/base.txt"], discipline = 'core, mitigates = [] },
      { id = "D2", title = "parallel a", depends_on = ["D1"],
        file_surface = ["demo/a.txt"], discipline = 'core, mitigates = [] },
      { id = "D3", title = "parallel b", depends_on = ["D1"],
        file_surface = ["demo/b.txt"], discipline = 'core, mitigates = [] },
      { id = "D4", title = "serial (shares a's surface)", depends_on = ["D1"],
        file_surface = ["demo/a.txt"], discipline = 'core, mitigates = [],
        serialize = true },
    ],
  } | c.Dag | c.DagNoConflict
)
