# PROBE: boundary skip-fail.
# The procedure OMITS the "attack" step (a boundary-specific required step).
# Footprint-presence bites: the upstream-pinned required set includes "attack",
# no step in the instance carries that id, so `nickel export` exits non-zero.
# EXPECT: fail
let b = import "../contracts/boundary_procedure.ncl" in
{
  instance | b.BoundaryProcedure = {
    workflow = "boundary-skip-attack",
    steps = [
      # CORE: track
      {
        id = "track",
        kind = 'leaf,
        evidence = [
          { claim = "tracker loaded", method = 'review, location = ".ledger/context_map.ncl" }
        ],
        cites = [".ledger/context_map.ncl"],
      },
      # CORE: adversarial-review
      {
        id = "adversarial-review",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "ar-1", role = "sub-procedure-output" },
      },
      # draft present
      {
        id = "draft",
        kind = 'leaf,
        evidence = [
          { claim = "draft IBC authored", method = 'lint, location = ".scratch/t/ibc.ncl" }
        ],
        cites = [".scratch/t/ibc.ncl"],
      },
      # "attack" DELIBERATELY OMITTED — footprint-presence must fail.
      # revise present
      {
        id = "revise",
        kind = 'leaf,
        evidence = [
          { claim = "objections resolved", method = 'review, location = ".scratch/t/ibc.ncl" }
        ],
        cites = [".scratch/t/ibc.ncl"],
      },
      # approve present
      {
        id = "approve",
        kind = 'leaf,
        evidence = [
          { claim = "human approved", method = 'manual, location = ".scratch/t/ibc.ncl" }
        ],
        cites = [".scratch/t/ibc.ncl"],
      },
    ],
  },
}
