# Campaign-IBC contract. The campaign IBC is the boundary a /campaign launches
# from: its METADATA (topic, lifecycle status) and CTX (the boundary path, the
# verbatim goal, the run mode, the scratch path). Mirrors the campaign grammar's
# METADATA + CONTEXT sections.
#
# Intrinsic gate (S5, tier economy): an AUTONOMOUS campaign may not launch from
# an empty goal — an unbounded autonomous walk is the failure mode tier economy
# exists to prevent. `nickel export` exits non-zero on mode 'autonomous with an
# empty goal.
{
  Ctx = {
    ibc_path | String,            # the approved boundary this campaign launches from
    goal | String,                # verbatim objective from the IBC
    mode | [| 'interactive, 'autonomous |],
    scratch_path | String,        # the .scratch/<topic> working set
  },

  # Record-shape contract: metadata plus the typed context.
  Campaign = {
    topic | String,
    status
      | [|
        'absorb,
        'clarify,
        'survey,
        'plan,
        'orchestrate,
        'dispatch,
        'reconcile,
        'close,
        'halt,
      |],
    ctx | Ctx,
  },

  # The goal gate, composed AFTER `Campaign` (like DagNoConflict after Dag):
  #   value | Campaign | CampaignIBC
  # so the record fields are merged before this custom contract reads them.
  CampaignIBC = std.contract.custom (fun _label value =>
    let ctx = value.ctx in
    if ctx.mode == 'autonomous && ctx.goal == ""
    then 'Error { message = "autonomous campaign launched from an empty goal" }
    else 'Ok value
  ),
}
