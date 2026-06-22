# EXPECT: fail
# Undeclared-conflict fixture: B and C are concurrent (neither depends on the
# other) AND both touch "shared/" with no serialize marker -> DagNoConflict MUST
# make `nickel export` exit non-zero (baseline delta-E0 != 0).
let c = import "../contracts/dag.ncl" in
(
  {
    nodes = [
      { id = "A", depends_on = [], file_surface = ["a/"], discipline = 'core, mitigates = [] },
      { id = "B", depends_on = ["A"], file_surface = ["shared/"], discipline = 'core, mitigates = [] },
      { id = "C", depends_on = ["A"], file_surface = ["shared/"], discipline = 'core, mitigates = [] },
    ]
  } | c.Dag
) | c.DagNoConflict
