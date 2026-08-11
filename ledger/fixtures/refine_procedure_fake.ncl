# PROBE: refine shaped-but-fake (the K4 seam).
# All 10 required steps are present; the leaf/invoke grammar is satisfied; the
# RefineOutput is structurally valid (non-empty targets, final_loop=1, sweeps=1,
# all maintainer_judgments 'approved). However:
#   - every leaf's evidence `claim` is the one-word "done" with 'review method
#     and a single-char location
#   - the postmortem is a single-char string (non-empty, passes; substance absent)
#   - fixed_point_hash is the string "x" (non-empty, passes; not a real SHA-256)
#   - maintainer judgment roles are single chars (non-empty, passes; not real personas)
#
# THE CONTRACT PASSES — the machine cannot distinguish substantive from hollow
# content when both are non-empty, well-typed values. The structural gate fires on
# presence + type, not on substance.
#
# FLAGGED FOR REVIEW: a reviewer inspecting this output will immediately see
# that all leaf claims are "done" and the postmortem is a single char. The review
# layer of the Verification Dual must close this.
#
# EXPECT: pass (contract) — flagged: review must judge substance
let r  = import "../../skills/refine/refine_procedure.ncl" in
let ro = import "../../skills/refine/refine_output.ncl" in
{
  steps_instance | r.RefineProcedure = {
    workflow = "refine",
    steps = [
      { id = "track",            kind = 'leaf,   evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ], cites = [] },
      { id = "adversarial-review", kind = 'invoke, class = "adversarial-review", ref = { target = "r1", role = "sub-procedure-output" } },
      { id = "absorb",           kind = 'leaf,   evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ], cites = [] },
      { id = "clarify",          kind = 'leaf,   evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ], cites = [] },
      { id = "audit",            kind = 'leaf,   evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ], cites = [] },
      { id = "iterate",          kind = 'leaf,   evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ], cites = [] },
      { id = "sweep",            kind = 'invoke, class = "adversarial-review", ref = { target = "r2", role = "sub-procedure-output" } },
      { id = "review",           kind = 'invoke, class = "adversarial-review", ref = { target = "r3", role = "sub-procedure-output" } },
      { id = "report",           kind = 'leaf,   evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ], cites = [] },
      { id = "halt",             kind = 'leaf,   evidence = [ { claim = "done", method = 'review, location = "x", signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" } } ], cites = [] },
    ],
  },

  # Structurally valid but hollow RefineOutput. final_loop=1 and
  # consecutive_clean_sweeps=1 clear the intrinsic gates; maintainer_judgments
  # is non-empty with 'approved; but role names are single chars and the
  # postmortem has no substance.
  output | ro.RefineReport | ro.RefineOutput = {
    workflow                 = "refine",
    target_artifacts         = ["x"],
    final_loop               = 1,
    consecutive_clean_sweeps = 1,
    maintainer_judgments     = [
      { role = "a", verdict = 'approved },
    ],
    postmortem       = "k",
    fixed_point_hash = "x",
  },
}
