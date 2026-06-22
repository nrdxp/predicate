# EXPECT: fail
# Cycle fixture: A->B->A. Acyclicity is intrinsic; `nickel export` MUST exit
# non-zero. This proves the baseline gate fires (delta-E0 != 0).
let c = import "../contracts/dag.ncl" in
{
  nodes = [
    { id = "A", depends_on = ["B"], file_surface = ["a/"], discipline = 'core, mitigates = [] },
    { id = "B", depends_on = ["A"], file_surface = ["b/"], discipline = 'core, mitigates = [] },
  ]
} | c.Dag
