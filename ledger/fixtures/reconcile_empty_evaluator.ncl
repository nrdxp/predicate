# EXPECT: fail
# Ungrounded-acceptance fixture (C-P3.3 for the reconcile log): P3 is judged
# 'accept but its evaluator is "". Accepting landed work without naming the gate
# that justified it is ungrounded -> the ReconcileLog contract MUST make
# `nickel export` exit non-zero (baseline delta-E0 != 0).
let c = import "../contracts/reconcile_log.ncl" in
{
  rounds = [
    {
      round = 1,
      judged = [
        { node = "P3", verdict = 'accept, evaluator = "" },
      ],
      freshness = [],
      realignments = [],
      checkpoint_commit = "d4b8fde",
    },
  ]
} | c.ReconcileLog
