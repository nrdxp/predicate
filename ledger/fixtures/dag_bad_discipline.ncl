# EXPECT: fail
# Bad-discipline fixture: a node declares an out-of-enum `discipline` ('bogus).
# Before the contract applied `Node` per element, this exported cleanly (the
# enum was inert). With per-element conformance forced in `Dag`, `nickel export`
# MUST exit non-zero (baseline delta-E0 != 0).
let c = import "../contracts/dag.ncl" in
(
  {
    nodes = [
      { id = "A", depends_on = [], file_surface = ["a/"], discipline = 'bogus, mitigates = [] },
    ]
  } | c.Dag
) | c.DagNoConflict
