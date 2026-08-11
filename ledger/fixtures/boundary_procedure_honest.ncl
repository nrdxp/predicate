# PROBE: boundary honest-pass.
# A well-formed instance of boundary_procedure composed with the WorkerIBC output
# contract. All 6 required steps are present (CoreSteps: "track",
# "adversarial-review"; boundary-specific: "draft", "attack", "revise",
# "approve"). The output field conforms to Worker ∘ WorkerIBC (non-empty goal,
# ≥1 acceptance criterion). Exports cleanly.
# EXPECT: pass
let b  = import "../../skills/boundary/boundary_procedure.ncl" in
let wi = import "../contracts/worker_ibc.ncl" in
let d  = import "../contracts/discipline.ncl" in
{
  # Step-footprint instance (the procedure spine)
  steps_instance | b.BoundaryProcedure = {
    workflow = "boundary",
    steps = [
      # CORE: track — R/I/U footprint
      {
        id = "track",
        kind = 'leaf,
        evidence = [
          { claim = "R/I/U tracker loaded from .ledger/context_map.ncl",
            method = 'review,
            signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" },
            location = ".ledger/context_map.ncl" }
        ],
        cites = [".ledger/context_map.ncl"],
      },

      # CORE: adversarial-review — decorrelated sweep of the draft IBC
      {
        id = "adversarial-review",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "ar-boundary-1", role = "sub-procedure-output" },
      },

      # DRAFT: author the candidate IBC document
      {
        id = "draft",
        kind = 'leaf,
        evidence = [
          { claim = "IBC candidate authored from templates/IBC.md",
            method = 'lint,
            signer = { kind = 'agent, name = "walker" }, check = { command = ".scratch/topic/campaign_ibc.ncl", ran = true, at = "6afbc9d" },
            location = ".scratch/topic/campaign_ibc.ncl" }
        ],
        cites = ["templates/IBC.md", ".scratch/topic/campaign_ibc.ncl"],
      },

      # ATTACK: adversarial S1–S7 sweep (cheap-tier reviewers)
      {
        id = "attack",
        kind = 'invoke,
        class = "adversarial-review",
        ref   = { target = "ar-boundary-2", role = "sub-procedure-output" },
      },

      # REVISE: resolve grounded objections from ATTACK
      {
        id = "revise",
        kind = 'leaf,
        evidence = [
          { claim = "all S1–S7 objections resolved or rebutted with evidence",
            method = 'review,
            signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" },
            location = ".scratch/topic/campaign_ibc.ncl" }
        ],
        cites = [".scratch/topic/campaign_ibc.ncl"],
      },

      # APPROVE: human gate — zero grounded objections; walk dispatched
      {
        id = "approve",
        kind = 'leaf,
        evidence = [
          { claim = "human approved IBC* after zero-objection ATTACK sweep",
            method = 'manual,
            signer = { kind = 'agent, name = "walker" }, witness = { name = "walker", at = "6afbc9d" },
            location = ".scratch/topic/campaign_ibc.ncl" }
        ],
        cites = [".scratch/topic/campaign_ibc.ncl"],
      },
    ],
  },

  # Output instance (the IBC* the boundary walk emits) — Worker ∘ WorkerIBC
  output | wi.Worker | wi.WorkerIBC = {
    id          = "ibc-example-worker",
    tier        = "worker/sonnet",
    discipline  = 'refine,
    depends_on  = [],
    goal        = "Exhaustively audit and converge ledger/contracts/procedure.ncl to its fixed-point S*.",
    non_goals   = ["implementing new features", "modifying sibling contracts not named in goal"],
    premises    = [
      { id        = "P1",
        statement = "procedure.ncl exists and typechecks",
        check     = "nix run nixpkgs#nickel -- typecheck -I ledger/contracts ledger/contracts/procedure.ncl",
        verified  = "2026-06-25 confirmed exit 0" }
    ],
    delegated   = ["step ordering within ITERATE", "choice of audit angles"],
    reserved    = ["amending procedure.ncl's CoreSteps set"],
    constraints = [
      { id        = "C1",
        statement = "all commits MUST pass the commit-gate",
        evaluator = "python3 skills/commit-hygiene/scripts/check_commit_msg.py --message MSG" }
    ],
    context_map = ["ledger/contracts/procedure.ncl:1-180", "skills/refine/SKILL.md:1-50"],
    acceptance  = [
      { id        = "AC1",
        statement = "procedure.ncl typechecks cleanly",
        eval      = "nix run nixpkgs#nickel -- typecheck -I ledger/contracts ledger/contracts/procedure.ncl; exit 0" }
    ],
    load_bearing = ["goal", "CoreSteps set"],
    plastic      = ["step ordering", "audit angle selection"],
  },
}
