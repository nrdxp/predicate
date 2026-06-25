# PROBE: refine skip-fail.
# The procedure OMITS the "sweep" step (a refine-specific required step).
# Footprint-presence bites: the upstream-pinned required set includes "sweep",
# no step in the instance carries that id, so `nickel export` exits non-zero.
# EXPECT: fail
let r = import "../../skills/refine/refine_procedure.ncl" in
{
  instance | r.RefineProcedure = {
    workflow = "refine-skips-sweep",
    steps = [
      {
        id = "track",
        kind = 'leaf,
        evidence = [ { claim = "tracker loaded", method = 'review, location = ".ledger/context_map.ncl" } ],
        cites = [".ledger/context_map.ncl"],
      },
      {
        id = "adversarial-review",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "ar-1", role = "sub-procedure-output" },
      },
      {
        id = "absorb",
        kind = 'leaf,
        evidence = [ { claim = "absorb complete", method = 'lint, location = ".worktrees/t" } ],
        cites = [".worktrees/t"],
      },
      {
        id = "clarify",
        kind = 'leaf,
        evidence = [ { claim = "no ambiguity", method = 'review, location = ".scratch/t.md" } ],
        cites = [".scratch/t.md"],
      },
      {
        id = "audit",
        kind = 'leaf,
        evidence = [ { claim = "ledger populated", method = 'lint, location = ".worktrees/t/x.ncl" } ],
        cites = [".worktrees/t/x.ncl"],
      },
      {
        id = "iterate",
        kind = 'leaf,
        evidence = [ { claim = "items resolved", method = 'example_test, location = ".worktrees/t" } ],
        cites = [".worktrees/t"],
      },
      # "sweep" DELIBERATELY OMITTED — footprint-presence must fail.
      {
        id = "review",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "mp-1", role = "sub-procedure-output" },
      },
      {
        id = "report",
        kind = 'leaf,
        evidence = [ { claim = "fixed point reached", method = 'review, location = ".scratch/t.md" } ],
        cites = [".scratch/t.md"],
      },
      {
        id = "halt",
        kind = 'leaf,
        evidence = [ { claim = "halt path defined", method = 'lint, location = "skills/refine/SKILL.md" } ],
        cites = ["skills/refine/SKILL.md"],
      },
    ],
  },
}
