# Positive-control fixture: a valid Selection for the "execution-workflow"
# match class. `chosen = "core"` is a registered member with fitness
# "implementing plan steps; TDD state machine with commit gates".
#
# Verified with:
#   nickel export -I ledger/contracts ledger/fixtures/arsenal_selection_match_valid.ncl
#   → exit 0

let registry = import "../contracts/arsenal_registry.ncl" in
let deposit   = import "../contracts/deposit.ncl" in

{
  id            = "sel-workflow-001",
  step          = "workflow-select",
  evidence      = [
    {
      claim    = "core workflow is the apt discipline for a TDD feature-implementation task",
      method   = 'review,
      location = "skills/core/SKILL.md: discipline = 'core; moment = implementing plan steps",
    }
  ],
  cites         = ["skills/core/SKILL.md"],
  refs          = [
    {
      target = "disc-workflow-001",
      role   = "discovery-footprint",
    }
  ],
  # Selection extension fields
  chosen        = "core",
  available     = ["core", "refine", "boundary", "campaign", "orchestration", "doc", "orient"],
  discovery_ref = {
    target = "disc-workflow-001",
    role   = "discovery-footprint",
  },
  justification = "The task is implementing a new feature under TDD; the 'core discipline's state machine (Absorb→Clarify→Plan→Execute with commit gates) is the apt fit. No multi-workstream coordination, no polish pass — core is cheapest_sufficient and apt.",
}
| (registry.make_selection registry.Arsenal "execution-workflow")
