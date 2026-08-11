# PROBE: skip-fail. The procedure OMITS an upstream-required step
# (`adversarial-review`, a CORE step). Footprint-presence bites: a required id
# has no matching step, so `nickel export` exits non-zero. This is non-skip — the
# walk cannot drop a required deposit.
# EXPECT: fail
let c = import "../contracts/procedure.ncl" in
let required = c.CoreSteps @ ["specify"] in
{
  instance | c.procedure required = {
    workflow = "drops-a-core-step",
    steps = [
      { id = "track", kind = 'leaf,
        evidence = [ { claim = "tracker fresh", method = 'review, location = "cm.ncl", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ],
        cites = ["cm.ncl"] },
      # `adversarial-review` deliberately MISSING — footprint-presence must fail.
      { id = "specify", kind = 'leaf,
        evidence = [ { claim = "spec authored", method = 'type_check, location = "s.ncl:1", signer = { kind = 'agent, name = "walker" }, check = { command = "s.ncl:1", ran = true, at = "6afbc9d" } } ],
        cites = ["s.ncl"] },
    ],
  },
}
