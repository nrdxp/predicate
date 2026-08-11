# PROBE: invoke-outside-registry-fail (I-C3, the machine-detectable no-spaghetti
# gate). A step `invoke`s a class that is NOT in the gated upstream sub-procedure
# registry (`sub_procedures.members`). This is the forbidden state: a skill reaching
# for an unregistered cross-procedure — exactly the spaghetti the registry exists to
# catch. The walk cannot legitimise it (the registry is upstream, not self-authored),
# so `nickel export` exits non-zero.
# EXPECT: fail
let c = import "../contracts/procedure.ncl" in
let required = c.CoreSteps @ ["specify"] in
{
  instance | c.procedure required = {
    workflow = "reaches-outside-registry",
    steps = [
      { id = "track", kind = 'leaf,
        evidence = [ { claim = "tracker fresh", method = 'review, location = "cm.ncl", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ],
        cites = ["cm.ncl"] },
      { id = "specify", kind = 'leaf,
        evidence = [ { claim = "spec authored", method = 'type_check, location = "s.ncl:1", signer = { kind = 'agent, name = "walker" }, check = { command = "s.ncl:1", ran = true, at = "6afbc9d" } } ],
        cites = ["s.ncl"] },
      # FORBIDDEN: `database-migration` is not a registered sub-procedure class.
      { id = "adversarial-review", kind = 'invoke,
        class = "database-migration",
        ref = { target = "x", role = "sub-procedure-output" } },
    ],
  },
}
