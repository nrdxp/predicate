# PROBE: process-gate skip-fail (boundary contract).
# The procedure OMITS the "attack" step (a boundary-specific required step).
# Footprint-presence bites: the upstream-pinned required set includes "attack",
# no step in the instance carries that id, so `nickel export` exits non-zero.
# Used by test_gates.sh to assert that process-gate.sh validate exits 1 on a
# skip deposit. Mirrors the boundary_procedure_skip.ncl probe but targets the
# process-gate.sh entry point rather than ledger-validate.sh structure.
# EXPECT: fail
let b = import "../contracts/boundary_procedure.ncl" in
{
  instance | b.BoundaryProcedure = {
    workflow = "boundary-skip-attack",
    steps = [
      {
        id = "track",
        kind = 'leaf,
        evidence = [
          { claim = "tracker loaded", method = 'review, location = ".ledger/context_map.ncl" }
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
          { claim = "draft authored", method = 'lint, location = ".scratch/t/ibc.ncl" }
        ],
        cites = [".scratch/t/ibc.ncl"],
      },
      # "attack" DELIBERATELY OMITTED — footprint-presence must fail.
      {
        id = "revise",
        kind = 'leaf,
        evidence = [
          { claim = "objections resolved", method = 'review, location = ".scratch/t/ibc.ncl" }
        ],
        cites = [".scratch/t/ibc.ncl"],
      },
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
