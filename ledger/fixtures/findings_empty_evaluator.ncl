# EXPECT: fail
# Ungrounded-resolution fixture (C-P3.3): F1 is marked 'mitigated but its
# evaluator, though named, was never RUN. A resolved finding whose closing
# check was only authored is ungrounded -> the Findings contract MUST make
# `nickel export` exit non-zero (baseline delta-E0 != 0).
let c = import "../contracts/findings.ncl" in
{
  findings = [
    {
      id = "F1",
      severity = 'high,
      statement = "Claimed resolved on a check that was only authored.",
      evidence = "see above",
      status = 'mitigated,
      evaluator = { command = "bash ledger/gate/test_findings.sh", ran = false, at = "6afbc9d" },
      signer = { kind = 'agent, name = "worker" },
      at = "6afbc9d",
    },
  ]
} | c.Findings
