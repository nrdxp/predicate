# Positive-control fixture: two nodes using the 'form and 'spec disciplines.
# Before the enum admits these tags, `nickel export` exits non-zero (baseline).
# After admitting 'form and 'spec to the discipline enum in dag.ncl,
# `nickel export` MUST exit 0 — both Dag and DagNoConflict pass.
let c = import "../contracts/dag.ncl" in
(
  {
    nodes = [
      {
        id = "F1",
        depends_on = [],
        file_surface = ["docs/"],
        discipline = 'form,
        mitigates = [],
      },
      {
        id = "F2",
        depends_on = ["F1"],
        file_surface = ["specs/"],
        discipline = 'spec,
        mitigates = [],
      },
    ]
  } | c.Dag
) | c.DagNoConflict
