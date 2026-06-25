# PROBE: process-gate skip-fail (boundary contract).
# The deposit OMITS the "attack" step (a boundary-specific required step).
# The gate applies BoundaryProcedure externally; footprint-presence fires
# because "attack" is absent. The deposit is a flat { workflow, steps } record
# with no inline contract import or binding — the gate is not fooled by a
# deposit that omits the self-binding, and must still catch the skip.
# Used by test_gates.sh to assert that process-gate.sh validate exits 1 on a
# skip deposit. NOTE: as a standalone artifact it is valid data and exports
# cleanly (positive structural control) — the skip is caught only when the gate
# applies the contract, which is the property under test.
{
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
}
