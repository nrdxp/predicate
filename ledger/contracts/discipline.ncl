# The canonical worker-discipline enum (T1.1). ONE definition of the surviving
# worker control loops, imported by every contract that names a discipline so the
# enum cannot drift between them.
#
# Why this file exists: the enum was declared in two places that disagreed —
# `dag.ncl` admitted [core, refine, doc, form, spec] while `worker_ibc.ncl`
# admitted only [core, refine]. A 'doc / 'form / 'spec node could pass the DAG
# contract yet never produce a conforming worker IBC: the campaign's own thesis
# (prose drifts; lift the invariant into one checked artifact) demonstrated in
# its own code. Unifying upstream makes the disagreement unrepresentable.
#
# The five surviving disciplines, each ONE control loop a worker walks (boundary
# S7 — exactly one disciplining workflow per IBC):
#   'core    feature work / TDD loop          (skills/core)
#   'refine  polish / contraction loop         (skills/refine)
#   'doc     documentation lifecycle           (skills/doc)
#   'form    formal domain modeling            (skills/form)
#   'spec    normative specification           (skills/spec)
{
  Discipline = [| 'core, 'refine, 'doc, 'form, 'spec |],
}
