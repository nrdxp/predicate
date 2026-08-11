# EXPECT: fail
# Negative control: duplicate id in ProcessFeedbackStore must make nickel
# export exit non-zero. Baseline delta-E0 != 0 — if this passes, the
# id-uniqueness gate has regressed. Mirrors tech_debt_dup_id.ncl; unlike that
# gate, this one had zero coverage anywhere in the repo before this fixture.
let c = import "../../skills/record/process_feedback.ncl" in
{
  items = [
    {
      id = "pf-x",
      kind = "friction",
      context = "First context",
      outcome = "First outcome",
      signer = { kind = 'agent, name = "worker" },
      at = "6afbc9d",
    },
    {
      id = "pf-x",
      kind = "improvement",
      context = "Duplicate id — store must reject this",
      outcome = "Second outcome",
      signer = { kind = 'agent, name = "worker" },
      at = "6afbc9d",
    },
  ]
} | c.ProcessFeedbackStore
