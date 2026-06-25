# PROBE: looped-step-pass. A procedure may iterate a step (a refinement/correction
# loop is the system's native shape). The combinator gates the required FOOTPRINT,
# not a linear one-pass control flow: the same logical concern recurs as DISTINCT
# step ids (`refine-pass-1`, `refine-pass-2`) — each a well-formed leaf depositing
# its own evidence. All upstream-required steps are present; the loop iterations
# ride alongside. Exports cleanly: legitimate iteration is not forbidden.
# EXPECT: pass
let c = import "../contracts/procedure.ncl" in
let required = c.CoreSteps @ ["specify"] in
{
  instance | c.procedure required = {
    workflow = "iterates-to-fixed-point",
    steps = [
      { id = "track", kind = 'leaf,
        evidence = [ { claim = "tracker fresh", method = 'review, location = "cm.ncl" } ],
        cites = ["cm.ncl"] },
      { id = "specify", kind = 'leaf,
        evidence = [ { claim = "spec authored", method = 'type_check, location = "s.ncl:1" } ],
        cites = ["s.ncl"] },
      # the correction loop: two iterations of the same concern as distinct ids,
      # each depositing its own iteration's evidence (the LOOPS:n discipline made
      # a footprint trail).
      { id = "refine-pass-1", kind = 'leaf,
        evidence = [ { claim = "iteration 1: 2 findings folded", method = 'example_test, location = "test.log:1" } ],
        cites = ["test.log"] },
      { id = "refine-pass-2", kind = 'leaf,
        evidence = [ { claim = "iteration 2: converged, dE=0", method = 'example_test, location = "test.log:42" } ],
        cites = ["test.log"] },
      { id = "adversarial-review", kind = 'invoke,
        class = "adversarial-review",
        ref = { target = "review-9", role = "sub-procedure-output" } },
    ],
  },
}
