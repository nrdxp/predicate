# Worker-IBC contract. A worker IBC is the boundary a single worker walk executes
# under. It renders the S1-S7 sufficiency shape of templates/IBC.md: metadata
# (including the S7 single discipline), the singular goal, non-goals, premises
# (S1), decision rights (S3), constraints (S4), context map (S5), acceptance
# criteria, and the amendment partition (S6).
#
# Intrinsic gate (boundary sufficiency): the template states that an empty
# section is a sufficiency violation, not a formality skipped. Two of those
# violations are deterministically checkable, so they are gated intrinsically:
# the goal MUST be non-empty (S0 — one objective per IBC) and there MUST be at
# least one acceptance criterion (without a definition of done the walk is
# unbounded). `nickel export` exits non-zero on either violation.
{
  # A falsifiable premise (S1): a statement plus the check that refutes it.
  Premise = {
    id | String,
    statement | String,
    check | String,               # exact command, file:line, or doc section
    verified | String,            # date/commit + evidence, or "UNVERIFIED"
  },

  # A grounded constraint (S4): a BCP-14 statement plus its evaluator.
  Constraint = {
    id | String,
    statement | String,
    evaluator | String,           # exact command or proof obligation
  },

  # An acceptance criterion: what done means, machine-checkable where possible.
  Criterion = {
    id | String,
    statement | String,
    eval | String,                # how it is checked
  },

  # Record-shape contract for the worker IBC.
  Worker = {
    id | String,
    tier | String,                # architect | worker + model class
    discipline | [| 'core, 'refine |],   # S7: exactly ONE control loop
    depends_on | Array String,    # upstream IBC IDs (premise-freshness keys)
    goal | String,                # S0: the singular objective
    non_goals | Array String,     # forbidden regions
    premises | Array Premise,     # S1
    delegated | Array String,     # S3: the walker's calls
    reserved | Array String,      # S3: halt predicates (the human's calls)
    constraints | Array Constraint,   # S4
    context_map | Array String,   # S5: pointers / verbatim excerpts
    acceptance | Array Criterion, # definition of done
    load_bearing | Array String,  # S6: amendment returns to the human
    plastic | Array String,       # S6: walker may revise with logged justification
  },

  # The sufficiency gate, composed AFTER `Worker` (like DagNoConflict after Dag):
  #   value | Worker | WorkerIBC
  WorkerIBC = std.contract.custom (fun _label value =>
    if value.goal == ""
    then 'Error { message = "worker IBC has an empty goal (sufficiency violation)" }
    else if std.array.length value.acceptance == 0
    then 'Error { message = "worker IBC has no acceptance criteria (unbounded walk)" }
    else 'Ok value
  ),
}
