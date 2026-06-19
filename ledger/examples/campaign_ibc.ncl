# Clean example: the predicate-cohesion campaign IBC. Exports 0.
let c = import "../contracts/campaign_ibc.ncl" in
(
  {
    topic = "predicate-cohesion",
    status = 'dispatch,
    ctx = {
      ibc_path = ".scratch/predicate-cohesion/prompts/campaign-ibc.md",
      goal = "Refactor predicate into one cohesive, machine-checkable, self-driving system.",
      mode = 'autonomous,
      scratch_path = ".scratch/predicate-cohesion",
    },
  } | c.Campaign
) | c.CampaignIBC
