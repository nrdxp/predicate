# EXPECT: fail
# Negative control: invalid `kind` value in ProcessFeedback must make nickel
# export exit non-zero. The Kind contract is value-restricted; an unlisted
# value must be rejected. Baseline delta-E0 != 0 — if this passes, the Kind
# enum constraint has regressed.
let c = import "../../skills/record/process_feedback.ncl" in
{
  items = [
    {
      id = "pf-y",
      kind = "unknown-kind",
      context = "Some context",
      outcome = "Some outcome",
    },
  ]
} | c.ProcessFeedbackStore
