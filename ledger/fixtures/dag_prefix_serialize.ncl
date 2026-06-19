# Prefix-serialize fixture: the same concurrent "docs/" vs "docs/x.md" overlap
# as dag_prefix_conflict.ncl, but B carries `serialize = true`. Path-containment
# overlap is detected, yet the serialize marker discharges the conflict, so
# `nickel export` MUST exit 0. This proves the prefix-aware overlap did not turn
# into a blanket reject: it still honours the serialize escape, exactly as the
# exact-string version did for byte-equal tokens.
let c = import "../contracts/dag.ncl" in
(
  {
    nodes = [
      { id = "A", depends_on = [], file_surface = ["docs/"], discipline = 'core, mitigates = [] },
      { id = "B", depends_on = [], file_surface = ["docs/x.md"], discipline = 'core, mitigates = [], serialize = true },
    ]
  } | c.Dag
) | c.DagNoConflict
