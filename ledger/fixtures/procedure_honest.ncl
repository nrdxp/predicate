# PROBE: honest-pass. A well-formed procedure for a hypothetical skill whose
# upstream-required set is the CORE steps plus one skill-specific step. Every
# required step is present; one is a leaf (deposits evidence+cites), the
# core-required `adversarial-review` is an invoke into the gated registry with a
# resolving ref; one extra non-required leaf rides alongside. Exports cleanly.
# EXPECT: pass
let c = import "../contracts/procedure.ncl" in
let required = c.CoreSteps @ ["specify"] in
{
  instance | c.procedure required = {
    workflow = "demo-skill",
    steps = [
      # core: track (a leaf depositing the R/I/U footprint)
      { id = "track", kind = 'leaf,
        evidence = [ { claim = "R/I/U tracker fresh vs HEAD", method = 'review, location = ".ledger/context_map.ncl", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ],
        cites = [".ledger/context_map.ncl"] },
      # core: adversarial-review (an invoke into the gated sub-procedure registry)
      { id = "adversarial-review", kind = 'invoke,
        class = "adversarial-review",
        ref = { target = "review-footprint-7", role = "sub-procedure-output" } },
      # skill-specific required leaf
      { id = "specify", kind = 'leaf,
        evidence = [ { claim = "invariant contract authored", method = 'type_check, location = "spec.ncl:1", signer = { kind = 'agent, name = "walker" }, check = { command = "spec.ncl:1", ran = true, at = "6afbc9d" } } ],
        cites = ["spec.ncl"] },
      # an extra, non-required leaf rides alongside (altitude: the walk may add steps)
      { id = "polish", kind = 'leaf,
        evidence = [ { claim = "naming pass applied", method = 'lint, location = "src/x:10", signer = { kind = 'agent, name = "walker" }, check = { command = "src/x:10", ran = true, at = "6afbc9d" } } ],
        cites = ["src/x"] },
    ],
  },
}
