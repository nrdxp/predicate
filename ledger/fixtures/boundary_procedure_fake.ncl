# PROBE: boundary shaped-but-fake (the K4 seam).
# All required steps are present; the leaf/invoke grammar is satisfied; the
# WorkerIBC output is structurally valid. However, the "evidence" in every leaf
# step is VACUOUS: the `claim` is a boilerplate assertion ("done"), the `method`
# is 'review (self-attestation), and the `location` is a single token that points
# to nothing real. The IBC* goal is one-word and acceptance is a tautology.
#
# THE CONTRACT PASSES — the machine cannot distinguish substantive from hollow
# evidence when both are non-empty, well-typed strings. This is the honest K4
# seam: the Verification Dual's probabilistic (review) layer must catch what the
# formal (structural) layer cannot.
#
# FLAGGED FOR REVIEW: a reviewer will find that every leaf says "done" with
# 'review method and a single-char location, and the IBC* goal is one word.
# EXPECT: pass (contract) — flagged: review must judge substance
let b  = import "../../skills/boundary/boundary_procedure.ncl" in
let wi = import "../contracts/worker_ibc.ncl" in
{
  steps_instance | b.BoundaryProcedure = {
    workflow = "boundary",
    steps = [
      {
        id = "track",
        kind = 'leaf,
        evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ],
        cites = [],
      },
      {
        id = "adversarial-review",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "r1", role = "sub-procedure-output" },
      },
      {
        id = "draft",
        kind = 'leaf,
        evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ],
        cites = [],
      },
      {
        id = "attack",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "r2", role = "sub-procedure-output" },
      },
      {
        id = "revise",
        kind = 'leaf,
        evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ],
        cites = [],
      },
      {
        id = "approve",
        kind = 'leaf,
        evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ],
        cites = [],
      },
    ],
  },

  # Structurally valid but hollow IBC* output. goal is non-empty (passes), one
  # acceptance criterion (passes), but the content is a tautology.
  output | wi.Worker | wi.WorkerIBC = {
    id          = "fake-ibc",
    tier        = "worker",
    discipline  = 'refine,
    depends_on  = [],
    goal        = "succeed",
    non_goals   = ["fail"],
    premises    = [
      { id = "P1", statement = "true", check = "true", verified = "yes" }
    ],
    delegated   = ["everything"],
    reserved    = ["nothing"],
    constraints = [],
    context_map = [],
    acceptance  = [
      { id = "AC1", statement = "it works", eval = "echo ok" }
    ],
    load_bearing = [],
    plastic      = [],
  },
}
