# PROBE: xor-violation-fail (I-C4, the leaf/invoke XOR — the adversarial-finding
# resolution). A single step does local work AND invokes — carrying BOTH a leaf
# payload (`evidence`) and an invoke payload (`class`/`ref`). The grammar is NOT
# relaxed to admit this: such a state must be SPLIT into two states. The Step
# contract rejects the conflated step, so `nickel export` exits non-zero.
# EXPECT: fail
let c = import "../contracts/procedure.ncl" in
let required = c.CoreSteps @ ["specify"] in
{
  instance | c.procedure required = {
    workflow = "conflates-leaf-and-invoke",
    steps = [
      { id = "track", kind = 'leaf,
        evidence = [ { claim = "tracker fresh", method = 'review, location = "cm.ncl" } ],
        cites = ["cm.ncl"] },
      { id = "specify", kind = 'leaf,
        evidence = [ { claim = "spec authored", method = 'type_check, location = "s.ncl:1" } ],
        cites = ["s.ncl"] },
      # FORBIDDEN: declares 'invoke but ALSO smuggles a leaf `evidence` payload.
      # The XOR must reject it — split into a leaf state and an invoke state.
      { id = "adversarial-review", kind = 'invoke,
        class = "adversarial-review",
        ref = { target = "r", role = "sub-procedure-output" },
        evidence = [ { claim = "also did local work", method = 'lint, location = "x:1" } ] },
    ],
  },
}
