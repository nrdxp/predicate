# EXPECT: fail
# Negative-control fixture: a deposit whose ref.target ("nonexistent-id") does
# not resolve to any declared deposit id. The DepositStore contract enforces
# referential integrity intrinsically; `nickel export` MUST exit non-zero
# (baseline delta-E0 != 0 — the dangling ref is detected eagerly).
let c = import "../contracts/deposit.ncl" in
{
  deposits = [
    {
      id = "deposit-alpha",
      step = "discovery",
      evidence = [
        {
          claim = "the outward-environment search confirmed the tool is available",
          method = 'example_test,
          location = "ledger/fixtures/deposit_dangling_ref.ncl:1",
          signer = { kind = 'agent, name = "survey-worker" },
          check = { command = "command -v nickel", ran = true, at = "6afbc9d" },
        },
      ],
      cites = [],
      refs = [
        # This ref.target does NOT correspond to any declared deposit id —
        # "nonexistent-id" is not in the deposits array above. The contract
        # must reject this instance.
        { target = "nonexistent-id", role = "prior-discovery" },
      ],
    },
  ],
} | c.DepositStore
