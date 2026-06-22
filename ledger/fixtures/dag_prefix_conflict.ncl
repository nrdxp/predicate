# EXPECT: fail
# Prefix-conflict fixture: A and B are concurrent (neither depends on the other)
# and their surfaces are "docs/" and "docs/x.md" — the file lies BENEATH the
# directory, so they genuinely collide. Exact-string overlap wrongly read these
# as disjoint and passed the gate; path-containment overlap catches it, so
# `nickel export` MUST exit non-zero with no serialize marker present
# (baseline delta-E0 != 0).
let c = import "../contracts/dag.ncl" in
(
  {
    nodes = [
      { id = "A", depends_on = [], file_surface = ["docs/"], discipline = 'core, mitigates = [] },
      { id = "B", depends_on = [], file_surface = ["docs/x.md"], discipline = 'core, mitigates = [] },
    ]
  } | c.Dag
) | c.DagNoConflict
