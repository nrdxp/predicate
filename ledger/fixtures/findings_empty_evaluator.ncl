# EXPECT: fail
# Empty-evaluator fixture (C-P3.3): F1 is marked 'mitigated but its evaluator is
# "". A resolved finding with no closing gate is ungrounded -> the Findings
# contract MUST make `nickel export` exit non-zero (baseline delta-E0 != 0).
let c = import "../contracts/findings.ncl" in
{
  findings = [
    {
      id = "F1",
      severity = 'high,
      statement = "Claimed resolved without naming the gate that closed it.",
      evidence = "see above",
      status = 'mitigated,
      evaluator = "",
    },
  ]
} | c.Findings
