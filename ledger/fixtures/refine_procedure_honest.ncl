# PROBE: refine honest-pass.
# A well-formed instance of refine_procedure composed with the RefineOutput
# contract. All 10 required steps are present (CoreSteps: "track",
# "adversarial-review"; refine-specific: "absorb", "clarify", "audit",
# "iterate", "sweep", "review", "report", "halt"). The repeatable steps "audit"
# and "iterate" each appear once under their canonical ids; a second audit cycle
# rides alongside as "audit-2" with a distinct id (does not violate uniqueness).
# The output RefineReport conforms to RefineOutput: non-empty targets, final_loop
# > 0, consecutive_clean_sweeps > 0, all maintainer_judgments 'approved.
# Exports cleanly.
# EXPECT: pass
let r   = import "../../skills/refine/refine_procedure.ncl" in
let ro  = import "../../skills/refine/refine_output.ncl" in
{
  # Step-footprint instance (the procedure spine)
  steps_instance | r.RefineProcedure = {
    workflow = "refine",
    steps = [
      # CORE: track — R/I/U footprint
      {
        id = "track",
        kind = 'leaf,
        evidence = [
          { claim = "R/I/U tracker re-surfaced; last_validated matches HEAD",
            method = 'review,
            signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" },
            location = ".ledger/context_map.ncl" }
        ],
        cites = [".ledger/context_map.ncl"],
      },

      # CORE: adversarial-review — the MBSS sweep step
      {
        id = "adversarial-review",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "mbss-sweep-round-1", role = "sub-procedure-output" },
      },

      # ABSORB: ingest artifact + initialize CTX
      {
        id = "absorb",
        kind = 'leaf,
        evidence = [
          { claim = "CTX.TARGET_ARTIFACTS set; worktree initialized at .worktrees/refine-topic; N_min=4 M_sweep=4 K_max=12",
            method = 'lint,
            signer = { kind = 'agent, name = "walker" }, check = { command = ".worktrees/refine-topic", ran = true, at = "6afbc9d" },
            location = ".worktrees/refine-topic" }
        ],
        cites = [".worktrees/refine-topic", ".scratch/topic/refine.md"],
      },

      # CLARIFY: ambiguity surfaced and resolved
      {
        id = "clarify",
        kind = 'leaf,
        evidence = [
          { claim = "scope ambiguity in goal resolved; assumption logged under CTX.ASSUMPTIONS",
            method = 'review,
            signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" },
            location = ".scratch/topic/refine.md:ASSUMPTIONS" }
        ],
        cites = [".scratch/topic/refine.md"],
      },

      # AUDIT: first audit cycle — populate REF_LEDGER
      {
        id = "audit",
        kind = 'leaf,
        evidence = [
          { claim = "REF_LEDGER populated; d_p(S_1)=3; linter + typecheck run",
            method = 'lint,
            signer = { kind = 'agent, name = "walker" }, check = { command = ".worktrees/refine-topic/ledger/contracts/procedure.ncl", ran = true, at = "6afbc9d" },
            location = ".worktrees/refine-topic/ledger/contracts/procedure.ncl" }
        ],
        cites = [".worktrees/refine-topic/ledger/contracts/procedure.ncl"],
      },

      # AUDIT-2: a second audit cycle (repeatable step, distinct id)
      {
        id = "audit-2",
        kind = 'leaf,
        evidence = [
          { claim = "REF_LEDGER empty after corrections; d_p(S_2)=0; linter clean",
            method = 'lint,
            signer = { kind = 'agent, name = "walker" }, check = { command = ".worktrees/refine-topic/ledger/contracts/procedure.ncl", ran = true, at = "6afbc9d" },
            location = ".worktrees/refine-topic/ledger/contracts/procedure.ncl" }
        ],
        cites = [".worktrees/refine-topic/ledger/contracts/procedure.ncl"],
      },

      # ITERATE: apply corrections to ledger items
      {
        id = "iterate",
        kind = 'leaf,
        evidence = [
          { claim = "R1, R2, R3 resolved; commits recorded in TRACE.LOOPS[1].COMMITS",
            method = 'example_test,
            signer = { kind = 'agent, name = "walker" }, check = { command = ".worktrees/refine-topic", ran = true, at = "6afbc9d" },
            location = ".worktrees/refine-topic" }
        ],
        cites = [".worktrees/refine-topic"],
      },

      # SWEEP: MBSS parallel adversarial sweep
      {
        id = "sweep",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "mbss-sweep-round-2", role = "sub-procedure-output" },
      },

      # REVIEW: hostile maintainer panel review
      {
        id = "review",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "maintainer-panel-1", role = "sub-procedure-output" },
      },

      # REPORT: emit final convergence report
      {
        id = "report",
        kind = 'leaf,
        evidence = [
          { claim = "fixed-point S* reached; CONSECUTIVE_CLEAN_SWEEPS=4 >= M_sweep=4; human approved",
            method = 'review,
            signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" },
            location = ".scratch/topic/refine.md:REPORT" }
        ],
        cites = [".scratch/topic/refine.md"],
      },

      # HALT: the exit step (the walk may not reach halt on a successful run;
      # the contract requires it present — the skeleton gates the option, not the
      # path taken)
      {
        id = "halt",
        kind = 'leaf,
        evidence = [
          { claim = "HALT state defined; worktree cleanup procedure documented",
            method = 'lint,
            signer = { kind = 'agent, name = "walker" }, check = { command = "skills/refine/SKILL.md:HALT", ran = true, at = "6afbc9d" },
            location = "skills/refine/SKILL.md:HALT" }
        ],
        cites = ["skills/refine/SKILL.md"],
      },
    ],
  },

  # Output instance — RefineReport | RefineOutput
  output | ro.RefineReport | ro.RefineOutput = {
    workflow                 = "refine",
    target_artifacts         = [
      "ledger/contracts/procedure.ncl",
      "ledger/contracts/core_steps.ncl",
    ],
    final_loop               = 4,
    consecutive_clean_sweeps = 4,
    maintainer_judgments     = [
      { role = "maintainer-architecture", verdict = 'approved },
      { role = "maintainer-complexity",   verdict = 'approved },
      { role = "maintainer-documentation", verdict = 'approved },
    ],
    postmortem = "The refiner overcorrected in loop 2 (added unnecessary helper fields later pruned in loop 3). Suggestion: run AUDIT with pruning check first. No scope deviations observed.",
    fixed_point_hash = "sha256:a3f1c2b4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2",
  },
}
