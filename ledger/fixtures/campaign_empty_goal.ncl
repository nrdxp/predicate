# Unbounded-autonomous fixture: mode 'autonomous with an empty goal. An
# autonomous campaign with no goal is the unbounded walk tier economy forbids ->
# the CampaignIBC contract MUST make `nickel export` exit non-zero (baseline
# delta-E0 != 0).
let c = import "../contracts/campaign_ibc.ncl" in
(
  {
    topic = "predicate-cohesion",
    status = 'dispatch,
    ctx = {
      ibc_path = ".scratch/predicate-cohesion/prompts/campaign-ibc.md",
      goal = "",
      mode = 'autonomous,
      scratch_path = ".scratch/predicate-cohesion",
    },
  } | c.Campaign
) | c.CampaignIBC
