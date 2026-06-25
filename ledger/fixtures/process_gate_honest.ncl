# PROBE: process-gate honest-pass (boundary contract).
# A minimal well-formed boundary procedure instance — all 6 required steps
# present (CoreSteps: "track", "adversarial-review"; boundary-specific:
# "draft", "attack", "revise", "approve"). Used by test_gates.sh to assert
# that process-gate.sh validate exits 0 on an honest deposit.
# EXPECT: pass
let b = import "../contracts/boundary_procedure.ncl" in
{
  instance | b.BoundaryProcedure = {
    workflow = "boundary",
    steps = [
      {
        id = "track",
        kind = 'leaf,
        evidence = [
          { claim = "R/I/U tracker loaded from .ledger/context_map.ncl",
            method = 'review,
            location = ".ledger/context_map.ncl" }
        ],
        cites = [".ledger/context_map.ncl"],
      },
      {
        id = "adversarial-review",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "ar-1", role = "sub-procedure-output" },
      },
      {
        id = "draft",
        kind = 'leaf,
        evidence = [
          { claim = "IBC candidate authored from templates/IBC.md",
            method = 'lint,
            location = ".scratch/topic/campaign_ibc.ncl" }
        ],
        cites = ["templates/IBC.md", ".scratch/topic/campaign_ibc.ncl"],
      },
      {
        id = "attack",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "ar-2", role = "sub-procedure-output" },
      },
      {
        id = "revise",
        kind = 'leaf,
        evidence = [
          { claim = "S1-S7 objections resolved with evidence",
            method = 'review,
            location = ".scratch/topic/campaign_ibc.ncl" }
        ],
        cites = [".scratch/topic/campaign_ibc.ncl"],
      },
      {
        id = "approve",
        kind = 'leaf,
        evidence = [
          { claim = "human approved IBC after zero-objection sweep",
            method = 'manual,
            location = ".scratch/topic/campaign_ibc.ncl" }
        ],
        cites = [".scratch/topic/campaign_ibc.ncl"],
      },
    ],
  },
}
