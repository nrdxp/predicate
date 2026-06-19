# Doc-discipline fixture: a node declares `discipline = 'doc` — a surviving
# worker workflow the enum omitted. With 'doc added to the enum AND `Node`
# applied per element, this MUST export cleanly (exit 0): the gate is real
# (it rejects 'bogus, see dag_bad_discipline.ncl) yet admits the legitimate
# 'doc discipline. A passing fixture under an enforced contract.
let c = import "../contracts/dag.ncl" in
(
  {
    nodes = [
      { id = "A", depends_on = [], file_surface = ["a/"], discipline = 'doc, mitigates = [] },
    ]
  } | c.Dag
) | c.DagNoConflict
