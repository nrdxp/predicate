# PROBE: shrink-required-fail (the F-REQ attack, K3 applied to the required-set
# itself). The walk attempts to SHRINK the discriminating set by smuggling its own
# `required` field into the INSTANCE — declaring only the steps it bothered to do
# and claiming that smaller set is what was required. The attack must FAIL: the
# upstream-bound `required` is a CONTRACT PARAMETER (bound below, outside the
# instance), so the instance's `required` field is inert noise. Footprint-presence
# still checks the FULL upstream set, the omitted `adversarial-review` is caught,
# and `nickel export` exits non-zero. The walk cannot author the set that judges it.
# EXPECT: fail
let c = import "../contracts/procedure.ncl" in
# The TRUE upstream-pinned required set — bound here, never from the instance.
let required = c.CoreSteps @ ["specify"] in
{
  instance | c.procedure required = {
    workflow = "tries-to-shrink",
    # The deceptive instance-level `required` — a smaller set the walk WISHES were
    # the gate. It is ignored by the contract (which uses the upstream `required`).
    required = ["track", "specify"],
    steps = [
      { id = "track", kind = 'leaf,
        evidence = [ { claim = "tracker fresh", method = 'review, location = "cm.ncl" } ],
        cites = ["cm.ncl"] },
      # `adversarial-review` omitted — the walk pretends it was never required.
      { id = "specify", kind = 'leaf,
        evidence = [ { claim = "spec authored", method = 'type_check, location = "s.ncl:1" } ],
        cites = ["s.ncl"] },
    ],
  },
}
