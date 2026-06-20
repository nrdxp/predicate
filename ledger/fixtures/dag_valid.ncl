# Positive-control fixture: a small, self-contained, valid campaign DAG.
# Three nodes, no cycle, no conflict, valid disciplines. Both `Dag` (acyclicity,
# referential integrity, id-uniqueness) and `DagNoConflict` (disjoint surfaces)
# pass — `nickel export` MUST exit 0.
#
# This is the shipped positive-control used by the gate demos (demo_unauthorized.sh,
# demo_scale_invariant.sh) and cited by ledger/README.md. It is synthetic — it
# carries no project-state — so downstream repos and CI can rely on it without
# pulling in live campaign data.
#
# Node P1 covers ledger/ (including ledger/gate/), satisfying the authority check
# in demo_unauthorized.sh (`authorize dag.ncl ledger/gate/ledger-validate.sh`) and
# the staged-change path used by demo_scale_invariant.sh (staged under ledger/gate/).
# No node covers src/, so demo_unauthorized.sh's rogue src/feature/ change is denied.
let c = import "../contracts/dag.ncl" in
(
  {
    nodes = [
      {
        id = "P1",
        depends_on = [],
        file_surface = ["ledger/"],
        discipline = 'core,
        mitigates = [],
      },
      {
        id = "P2",
        depends_on = ["P1"],
        file_surface = ["skills/"],
        discipline = 'doc,
        mitigates = [],
      },
      {
        id = "P3",
        depends_on = ["P1"],
        file_surface = ["gates/"],
        discipline = 'core,
        mitigates = [],
      },
    ]
  } | c.Dag
) | c.DagNoConflict
