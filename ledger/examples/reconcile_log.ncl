# Clean example: a reconcile log where every accepted node names the gate that
# justified acceptance. Exports 0.
let c = import "../contracts/reconcile_log.ncl" in
{
  rounds = [
    {
      round = 1,
      judged = [
        {
          node = "P3",
          verdict = 'accept,
          evaluator = "nix run nixpkgs#nickel -- export over every contract, example, and fixture",
        },
        {
          node = "P4",
          verdict = 'rework,
          evaluator = "",
        },
        {
          node = "P9",
          verdict = 'escalate,
          evaluator = "",
        },
      ],
      freshness = [
        { node = "P4", state = 'stale },
        { node = "P5", state = 'fresh },
      ],
      realignments = [
        "P4 prompt revised: gate command must be portable (direct nickel XOR nix run).",
      ],
      checkpoint_commit = "d4b8fde",
    },
  ]
} | c.ReconcileLog
