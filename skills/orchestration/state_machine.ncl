# Orchestrator state machine — R1 (architecture-model).
#
# The core orchestrator is formalised as a two-layer state machine:
#
#   Layer 0 — architect control loop  (/campaign):
#     ABSORB → CLARIFY → SURVEY → PLAN → ORCHESTRATE → DISPATCH ⇄ RECONCILE → CLOSE
#
#   Layer 1 — runnable driver  (/orchestration):
#     DERIVE → RUN_LAYER → DISPATCH → AWAIT → [SURFACE_EXCEED] → RECONCILE
#             → MERGE → BOUNDARY → CHECKPOINT → [REALIGN] → CLOSE
#
# PURPOSE of this file (from architecture.md, R1):
#   Compose the five existing checked artifacts —
#     campaign_ibc, findings, dag, worker_ibc, reconcile_log —
#   as per-transition EXIT-GUARDS so that the state-machine topology is itself
#   a checked artifact. `nickel export` over this file IS the topology gate.
#
# ALTITUDE CAVEAT (architecture.md §core-state-machine, design-rule 2):
#   This file gates SEAMS / TRANSITIONS — whether you may leave a state.
#   It does NOT prescribe the creative interior of any state. A state earns a
#   contract only when it has a checkable pre/post-condition; the rest stays
#   in prose (campaign/SKILL.md + orchestration/SKILL.md).
#
# AMENDMENT LOOPS (architecture.md §empirical-grounding):
#   Back-edges RECONCILE→PLAN and PLAN→PLAN are first-class transitions, not
#   deviations. The machine carries them explicitly so an amendment is a checked
#   state, not an undocumented escape hatch.
#
# GUARD-LOCUS PRINCIPLE (architecture.md §gate-locus-principle):
#   Architectural validity is proven ONCE at the seam (nickel export, architect-
#   time). Per-commit gates are the high-frequency worker-commit floor.
#   This file is the architect-time check; it does not duplicate commit-gate logic.
#
# Verification:
#   CONTRACT DEFINITIONS (this file):
#     nickel typecheck skills/orchestration/state_machine.ncl
#   INSTANCE / FIXTURE (the exportable topology gate):
#     nickel export ledger/fixtures/state_machine_topology.ncl
{
  # ── Imports (the five existing artifact contracts) ───────────────────────────
  # Each is imported by RELATIVE PATH (resolved from skills/orchestration/) so the
  # contracts are composed, not duplicated. Shared substrate lives in ledger/contracts/.
  # A change to dag.ncl propagates automatically to this guard.
  CampaignIBC  = (import "../../ledger/contracts/campaign_ibc.ncl").CampaignIBC,
  Findings     = (import "../../ledger/contracts/findings.ncl").Findings,
  Dag          = (import "../../ledger/contracts/dag.ncl").Dag,
  DagNoConflict = (import "../../ledger/contracts/dag.ncl").DagNoConflict,
  WorkerIBC    = (import "../../ledger/contracts/worker_ibc.ncl").WorkerIBC,
  ReconcileLog = (import "../../ledger/contracts/reconcile_log.ncl").ReconcileLog,

  # ── Shared primitives ────────────────────────────────────────────────────────

  # Non-empty string sentinel — mirrors context_map.ncl/deposit.ncl pattern.
  NonEmptyString = std.contract.from_predicate (fun value =>
    std.is_string value && std.string.length value > 0
  ),

  # ── Layer 0 — Campaign state identifiers ────────────────────────────────────
  # Mirrors campaign_ibc.ncl `status` enum; kept in sync by shared import.
  # (CampaignIBC already enforces `status` shape on any campaign record;
  #  this enum is re-declared here so the transition table can reference it as
  #  a type annotation without depending on a campaign instance being in scope.)
  L0State = [|
    'ABSORB,
    'CLARIFY,
    'SURVEY,
    'PLAN,
    'ORCHESTRATE,
    'DISPATCH,
    'RECONCILE,
    'CLOSE,
    'HALT,
  |],

  # ── Layer 1 — Orchestration state identifiers ────────────────────────────────
  # Mirrors skills/orchestration/SKILL.md §driver-state-machine.
  L1State = [|
    'DERIVE,
    'RUN_LAYER,
    'DISPATCH,
    'AWAIT,
    'SURFACE_EXCEED,
    'RECONCILE,
    'MERGE,
    'BOUNDARY,
    'CHECKPOINT,
    'REALIGN,
    'CLOSE,
    'HALT,
  |],

  # ── Transition — the unit of the state machine ───────────────────────────────
  # Each transition names its FROM state, its TO state, what artifact it exits
  # (the guard input: what file/record conforms to the guard contract), and a
  # human-readable summary of the guard condition.
  #
  # GUARD FIELD SEMANTICS:
  #   guard_contract  — the Nickel contract name (from this file's exported
  #                     namespace) that the artifact at guard_artifact must
  #                     satisfy before the transition fires.
  #   guard_artifact  — the path / logical name of the artifact being checked.
  #   guard_note      — the prose statement of the seam condition (for reviewers;
  #                     not machine-checked).
  #
  # HUMAN SEAM:
  #   Transitions that require human approval are marked human_seam = true.
  #   The machine cannot enforce human decisions; it records the requirement.
  #   human_seam absent or false → deterministically checkable.
  Transition = {
    from          | String,         # source state label
    to            | String,         # target state label
    guard_contract | String,        # contract name in this record
    guard_artifact | String,        # the artifact path / logical pointer
    guard_note    | NonEmptyString, # prose summary of the exit condition
    human_seam    | Bool,           # true → human approval required at this seam
    layer         | [| 'L0, 'L1, 'both |],  # which layer this transition belongs to
  },

  # ── Layer 0 transition table (Campaign / /campaign) ─────────────────────────
  # Source of truth: campaign/SKILL.md §State-Transitions + §States.
  # Amendment back-edges (RECONCILE→PLAN, PLAN→PLAN) are first-class (empirical
  # grounding, architecture.md §empirical-grounding).
  L0Transitions = [

    # ABSORB → CLARIFY : premise audit found ambiguity or contradiction
    {
      from           = "ABSORB",
      to             = "CLARIFY",
      guard_contract = "CampaignIBC",
      guard_artifact = ".scratch/<topic>/campaign_ibc record",
      guard_note     = "Campaign record conforms to CampaignIBC; mode/goal gate passes. Transition fires when premise audit surfaces ambiguity — the IBC shape was still structurally valid but semantically unresolved.",
      human_seam     = false,
      layer          = 'L0,
    },

    # ABSORB → SURVEY : IBC* premises verified, scratch initialized
    {
      from           = "ABSORB",
      to             = "SURVEY",
      guard_contract = "CampaignIBC",
      guard_artifact = ".scratch/<topic>/campaign_ibc record",
      guard_note     = "Campaign record conforms to CampaignIBC (non-empty goal, valid mode). Premises verified against primary sources; no ambiguity.",
      human_seam     = false,
      layer          = 'L0,
    },

    # CLARIFY → SURVEY : ambiguity resolved
    {
      from           = "CLARIFY",
      to             = "SURVEY",
      guard_contract = "CampaignIBC",
      guard_artifact = ".scratch/<topic>/campaign_ibc record",
      guard_note     = "Resolution recorded; IBC still conforms to CampaignIBC. Rejected frames return to /boundary, not SURVEY.",
      human_seam     = false,
      layer          = 'L0,
    },

    # CLARIFY → HALT : frame rejected; boundary loop must reconsider
    {
      from           = "CLARIFY",
      to             = "HALT",
      guard_contract = "CampaignIBC",
      guard_artifact = ".scratch/<topic>/campaign_ibc record",
      guard_note     = "Frame rejected (premise refuted). Guard is the CampaignIBC shape; the rejection report is the artifact, not a contract failure. Human seam: human must reconsider the boundary.",
      human_seam     = true,
      layer          = 'L0,
    },

    # SURVEY → PLAN : findings ledger complete and evidence-grounded
    {
      from           = "SURVEY",
      to             = "PLAN",
      guard_contract = "Findings",
      guard_artifact = ".scratch/<topic>/findings (the REVIEW.md findings ledger)",
      guard_note     = "Findings ledger conforms to Findings contract: no resolved finding has an empty evaluator; no duplicate finding ids.",
      human_seam     = false,
      layer          = 'L0,
    },

    # PLAN → ORCHESTRATE : human approves the plan (interactive mode)
    {
      from           = "PLAN",
      to             = "ORCHESTRATE",
      guard_contract = "DagNoConflict",
      guard_artifact = ".scratch/<topic>/dag.yaml (campaign DAG)",
      guard_note     = "DAG passes Dag ∘ DagNoConflict: acyclic, referentially whole, concurrent nodes have disjoint file_surface or serialize marker. In INTERACTIVE mode, human approval is also required before dispatch.",
      human_seam     = true,
      layer          = 'L0,
    },

    # PLAN → PLAN : amendment loop (back-edge — plan itself was wrong; empirical grounding)
    {
      from           = "PLAN",
      to             = "PLAN",
      guard_contract = "DagNoConflict",
      guard_artifact = ".scratch/<topic>/dag.yaml (amended campaign DAG)",
      guard_note     = "DAG amendment: re-export must pass Dag ∘ DagNoConflict. Human approval of the amended plan before re-entering ORCHESTRATE (boundary S3: amendment is a load-bearing call).",
      human_seam     = true,
      layer          = 'L0,
    },

    # PLAN → HALT : goal unreachable within appetite
    {
      from           = "PLAN",
      to             = "HALT",
      guard_contract = "Dag",
      guard_artifact = ".scratch/<topic>/dag.yaml",
      guard_note     = "DAG exists (Dag passes) but goal unreachable; architect surfaces a report to the human. The contract checks structural validity, not reachability — reachability is adversarial-path (A).",
      human_seam     = true,
      layer          = 'L0,
    },

    # ORCHESTRATE → DISPATCH : worker IBCs emitted and routing table approved
    {
      from           = "ORCHESTRATE",
      to             = "DISPATCH",
      guard_contract = "WorkerIBC",
      guard_artifact = ".scratch/<topic>/prompts/<node>-*.md worker IBC records",
      guard_note     = "Every emitted worker IBC conforms to Worker ∘ WorkerIBC: non-empty goal, ≥1 acceptance criterion, single discipline. In INTERACTIVE mode, human approves the routing table before dispatch.",
      human_seam     = true,
      layer          = 'L0,
    },

    # DISPATCH → RECONCILE : one or more nodes land (or a worker freezes)
    {
      from           = "DISPATCH",
      to             = "RECONCILE",
      guard_contract = "ReconcileLog",
      guard_artifact = ".scratch/<topic>/reconcile_log (the active RECONCILE_LOG)",
      guard_note     = "A reconcile log entry is opened for this round (ReconcileLog shapes the log). Workers have returned or frozen; judgments are pending.",
      human_seam     = false,
      layer          = 'L0,
    },

    # RECONCILE → DISPATCH : accepted; fresh pending nodes remain
    {
      from           = "RECONCILE",
      to             = "DISPATCH",
      guard_contract = "ReconcileLog",
      guard_artifact = ".scratch/<topic>/reconcile_log",
      guard_note     = "RECONCILE_LOG round appended: every ACCEPT judgment has a non-empty evaluator. Pending nodes re-verified fresh (premise_fresh.sh). Sketch checkpoint committed.",
      human_seam     = false,
      layer          = 'L0,
    },

    # RECONCILE → ORCHESTRATE : realignment requires new/revised worker IBCs
    {
      from           = "RECONCILE",
      to             = "ORCHESTRATE",
      guard_contract = "ReconcileLog",
      guard_artifact = ".scratch/<topic>/reconcile_log",
      guard_note     = "RECONCILE round appended (log valid). Structural fault at node level requires new IBCs; architect re-enters ORCHESTRATE to emit corrective boundaries (still conforms to WorkerIBC before dispatch).",
      human_seam     = false,
      layer          = 'L0,
    },

    # RECONCILE → PLAN : structural fault — the plan itself was wrong (amendment loop)
    {
      from           = "RECONCILE",
      to             = "PLAN",
      guard_contract = "ReconcileLog",
      guard_artifact = ".scratch/<topic>/reconcile_log",
      guard_note     = "RECONCILE round appended. ESCALATE verdict: plan-level fault. Back-edge to PLAN; amended DAG must re-pass Dag ∘ DagNoConflict and receive human approval before re-dispatch.",
      human_seam     = true,
      layer          = 'L0,
    },

    # RECONCILE → CLOSE : all findings MITIGATED or ACCEPTED_RISK; DAG complete
    {
      from           = "RECONCILE",
      to             = "CLOSE",
      guard_contract = "ReconcileLog",
      guard_artifact = ".scratch/<topic>/reconcile_log",
      guard_note     = "RECONCILE_LOG valid; every node ACCEPTED; Findings ledger shows all findings mitigated or accepted_risk (cross-checked against findings.ncl).",
      human_seam     = false,
      layer          = 'L0,
    },

    # RECONCILE → HALT : reserved predicate tripped or budget exhausted
    {
      from           = "RECONCILE",
      to             = "HALT",
      guard_contract = "ReconcileLog",
      guard_artifact = ".scratch/<topic>/reconcile_log",
      guard_note     = "RECONCILE round appended. Reserved predicate fired or budget exhausted. Human seam: a reserved predicate is, by definition, a human call.",
      human_seam     = true,
      layer          = 'L0,
    },

    # CLOSE → end : final sweep passes; human accepts the report
    {
      from           = "CLOSE",
      to             = "HALT",
      guard_contract = "ReconcileLog",
      guard_artifact = ".scratch/<topic>/reconcile_log (final round)",
      guard_note     = "Final sweep: full deterministic verification surface passes; MBSS sweep converged; retrospective committed in .ledger/log/; recorder_close_check.sh exits 0. Human seam: final acceptance before any push.",
      human_seam     = true,
      layer          = 'L0,
    },

    # CLOSE → RECONCILE : final sweep found regressions
    {
      from           = "CLOSE",
      to             = "RECONCILE",
      guard_contract = "ReconcileLog",
      guard_artifact = ".scratch/<topic>/reconcile_log",
      guard_note     = "Final sweep surfaced regressions (deterministic gate or MBSS). Route back to RECONCILE to address before CLOSE re-entry.",
      human_seam     = false,
      layer          = 'L0,
    },
  ],

  # ── Layer 1 transition table (Orchestration driver / /orchestrate) ───────────
  # Source of truth: skills/orchestration/SKILL.md §driver-state-machine.
  # This layer refines L0's DISPATCH ⇄ RECONCILE into a wired automaton.
  L1Transitions = [

    # DERIVE : validate DAG + derive schedule; write active-dag pointer
    {
      from           = "START",
      to             = "DERIVE",
      guard_contract = "DagNoConflict",
      guard_artifact = "bound DAG file (default: .ledger/state/dag.yaml)",
      guard_note     = "nickel export DAG exits 0 (Dag ∘ DagNoConflict). Schedule derived: nickel export LAYERS → {layer_count, layers}. Active-dag pointer written ($root/.ledger/active-dag).",
      human_seam     = false,
      layer          = 'L1,
    },

    # DERIVE → HALT : DAG malformed; not a driver decision
    {
      from           = "DERIVE",
      to             = "HALT",
      guard_contract = "Dag",
      guard_artifact = "bound DAG file",
      guard_note     = "DAG export fails (Dag or DagNoConflict violated). Driver cannot proceed; surface diagnostic. Not a driver call — escalate.",
      human_seam     = true,
      layer          = 'L1,
    },

    # DERIVE → RUN_LAYER : DAG valid, schedule ready
    {
      from           = "DERIVE",
      to             = "RUN_LAYER",
      guard_contract = "DagNoConflict",
      guard_artifact = "bound DAG file",
      guard_note     = "DAG passes Dag ∘ DagNoConflict; layer schedule exported; shared_branch created from HEAD; k := 0.",
      human_seam     = false,
      layer          = 'L1,
    },

    # RUN_LAYER → DISPATCH : layer partitioned into parallel + serial sets
    {
      from           = "RUN_LAYER",
      to             = "DISPATCH",
      guard_contract = "DagNoConflict",
      guard_artifact = "layers[k] partition (a read of the already-validated DAG)",
      guard_note     = "Layer k nodes partitioned: serial (serialize=true) vs parallel. DagNoConflict already proved the parallel set disjoint — this is a read of that proof, not a re-computation.",
      human_seam     = false,
      layer          = 'L1,
    },

    # DISPATCH → AWAIT : all layer-k nodes dispatched
    {
      from           = "DISPATCH",
      to             = "AWAIT",
      guard_contract = "WorkerIBC",
      guard_artifact = "prompts/<node-id>-*.md handed to each worker",
      guard_note     = "Each dispatched worker received its IBC (WorkerIBC-conformant). Worktrees created; STATUS := DISPATCHED. Driver awaits worker returns.",
      human_seam     = false,
      layer          = 'L1,
    },

    # AWAIT → SURFACE_EXCEED : a worker froze on surface-exceed
    {
      from           = "AWAIT",
      to             = "SURFACE_EXCEED",
      guard_contract = "WorkerIBC",
      guard_artifact = "worker freeze report (surface-exceed variant)",
      guard_note     = "Worker returned a surface-exceed freeze. Driver runs authorized.py --collision-check to resolve (WIDEN or SERIALIZE). Guard: the freeze report nominates the exceeded surface — checkable against the worker's declared file_surface in its IBC.",
      human_seam     = false,
      layer          = 'L1,
    },

    # AWAIT → RECONCILE : all dispatched workers returned
    {
      from           = "AWAIT",
      to             = "RECONCILE",
      guard_contract = "ReconcileLog",
      guard_artifact = ".ledger/state/reconcile_log.ncl (active log)",
      guard_note     = "Workers returned; reconcile round opened in the log. ReconcileLog contract shapes the log; a round record is opened (no accept verdicts yet → no evaluator requirement yet).",
      human_seam     = false,
      layer          = 'L1,
    },

    # AWAIT → HALT : non-resolvable reserved halt from a worker
    {
      from           = "AWAIT",
      to             = "HALT",
      guard_contract = "WorkerIBC",
      guard_artifact = "worker freeze report (reserved-predicate variant)",
      guard_note     = "Worker tripped a reserved predicate (a human call by definition). Human seam: surface the freeze report; escalate.",
      human_seam     = true,
      layer          = 'L1,
    },

    # SURFACE_EXCEED → AWAIT : surface widened or serialized; worker resumed
    {
      from           = "SURFACE_EXCEED",
      to             = "AWAIT",
      guard_contract = "DagNoConflict",
      guard_artifact = "amended DAG after WIDEN or SERIALIZE re-export",
      guard_note     = "authorized.py --collision-check: rc 0 (WIDEN) → node surface widened, DAG re-exported (Dag ∘ DagNoConflict), worker resumed. rc 3 (SERIALIZE) → node marked serialize=true, DAG re-exported, schedule re-derived.",
      human_seam     = false,
      layer          = 'L1,
    },

    # RECONCILE → MERGE : node ACCEPTED (all boundary checks passed)
    {
      from           = "RECONCILE",
      to             = "MERGE",
      guard_contract = "ReconcileLog",
      guard_artifact = ".ledger/state/reconcile_log.ncl",
      guard_note     = "ACCEPT verdict for this node: evaluator re-run passes (gate exit 0); surface honesty check clean; coherence-impact clean (or decorrelated reviews converged). ReconcileLog: accept judgment has non-empty evaluator.",
      human_seam     = false,
      layer          = 'L1,
    },

    # RECONCILE → DISPATCH : REWORK — emit corrective delta IBC, re-dispatch
    {
      from           = "RECONCILE",
      to             = "DISPATCH",
      guard_contract = "WorkerIBC",
      guard_artifact = "corrective delta IBC for the rework node",
      guard_note     = "REWORK verdict: evaluator, surface, or coherence check failed. Corrective delta IBC emitted (WorkerIBC-conformant). Node STATUS := PENDING; re-dispatched from current tip.",
      human_seam     = false,
      layer          = 'L1,
    },

    # RECONCILE → REALIGN : ESCALATE — structural fault in plan or topology
    {
      from           = "RECONCILE",
      to             = "REALIGN",
      guard_contract = "DagNoConflict",
      guard_artifact = "amended DAG after topology realignment",
      guard_note     = "ESCALATE verdict: fault is structural (plan-level, not node-level). Driver enters REALIGN to rewrite the node's premises/surface, then re-exports DAG (must pass Dag ∘ DagNoConflict).",
      human_seam     = false,
      layer          = 'L1,
    },

    # MERGE → CHECKPOINT : node branch merged into shared_branch
    {
      from           = "MERGE",
      to             = "CHECKPOINT",
      guard_contract = "ReconcileLog",
      guard_artifact = ".ledger/state/reconcile_log.ncl",
      guard_note     = "Node branch merged (--no-ff or octopus per situation). STATUS := ACCEPTED; mitigated findings marked. ReconcileLog accept judgment has evaluator. Checkpoint pending.",
      human_seam     = false,
      layer          = 'L1,
    },

    # CHECKPOINT → RECONCILE : more nodes remain in this layer
    {
      from           = "CHECKPOINT",
      to             = "RECONCILE",
      guard_contract = "ReconcileLog",
      guard_artifact = ".ledger/state/reconcile_log.ncl",
      guard_note     = "RECONCILE_LOG round appended; sketch checkpoint committed in recorder. More LANDED nodes in this layer remain to reconcile.",
      human_seam     = false,
      layer          = 'L1,
    },

    # CHECKPOINT → BOUNDARY : all nodes in this layer reconciled
    {
      from           = "CHECKPOINT",
      to             = "BOUNDARY",
      guard_contract = "ReconcileLog",
      guard_artifact = ".ledger/state/reconcile_log.ncl",
      guard_note     = "All nodes in layer k reconciled. RECONCILE_LOG round committed in recorder. Driver enters BOUNDARY for cumulative-diff coherence gate before advancing the tip.",
      human_seam     = false,
      layer          = 'L1,
    },

    # BOUNDARY → RUN_LAYER : coherent; advance tip; k++
    {
      from           = "BOUNDARY",
      to             = "RUN_LAYER",
      guard_contract = "DagNoConflict",
      guard_artifact = "coherence_impact.sh exit 0 over layer cumulative diff + DAG state",
      guard_note     = "coherence_impact.sh exits 0 (contract export, orphan gate, link gate all pass). No DAG amendment needed. tip := shared_branch HEAD; k++; next layer starts. DagNoConflict is re-verified if topology changed.",
      human_seam     = false,
      layer          = 'L1,
    },

    # BOUNDARY → RUN_LAYER (human seam) : DAG amendment approved; tip advanced
    {
      from           = "BOUNDARY",
      to             = "RUN_LAYER",
      guard_contract = "DagNoConflict",
      guard_artifact = "amended DAG re-exported after human approval",
      guard_note     = "coherence_impact.sh exits 0; DAG amendment warranted (Goal Supremacy). Human seam: architect surfaces amendment; human approves; DAG re-exported (Dag ∘ DagNoConflict); tip advanced.",
      human_seam     = true,
      layer          = 'L1,
    },

    # BOUNDARY → CLOSE : k was last layer
    {
      from           = "BOUNDARY",
      to             = "CLOSE",
      guard_contract = "ReconcileLog",
      guard_artifact = ".ledger/state/reconcile_log.ncl",
      guard_note     = "coherence_impact.sh exits 0; all layers processed (k+1 == layer_count). Transition to CLOSE.",
      human_seam     = false,
      layer          = 'L1,
    },

    # BOUNDARY → HALT : INCOHERENT — cross-node reference broken; escalate
    {
      from           = "BOUNDARY",
      to             = "HALT",
      guard_contract = "ReconcileLog",
      guard_artifact = "coherence_impact.sh diagnostic (rc 1)",
      guard_note     = "coherence_impact.sh exits 1: a cut/rename orphaned a cross-node reference. Fault is not localizable to one node; escalate to PLAN. Human seam: architect realigns the plan for the cross-node coupling before re-dispatch.",
      human_seam     = true,
      layer          = 'L1,
    },

    # REALIGN → DISPATCH : premises rewritten; schedule may have changed
    {
      from           = "REALIGN",
      to             = "DISPATCH",
      guard_contract = "DagNoConflict",
      guard_artifact = "DAG after realignment (re-exported if surfaces changed)",
      guard_note     = "Node premises/surface rewritten to current HEAD. If topology/surfaces changed, DAG re-exported (Dag ∘ DagNoConflict); schedule re-derived. STATUS := PENDING. Node re-dispatched from current tip.",
      human_seam     = false,
      layer          = 'L1,
    },

    # CLOSE : all findings + nodes accepted; full suite + MBSS + retrospective
    {
      from           = "CLOSE",
      to             = "HALT",
      guard_contract = "ReconcileLog",
      guard_artifact = ".ledger/state/reconcile_log.ncl (final) + recorder_close_check.sh",
      guard_note     = "All findings MITIGATED/accepted_risk; all nodes ACCEPTED; full deterministic surface passes; process-adherence gate (adherence_audit.sh) exits 0; MBSS sweep converged; retrospective committed (recorder_close_check.sh exits 0); active-dag pointer cleared. Human seam: final acceptance + push.",
      human_seam     = true,
      layer          = 'L1,
    },
  ],

  # ── State-machine record (the checked topology) ──────────────────────────────
  # Composes L0 and L1 transition tables into one record. `nickel export` over
  # this file IS the topology gate: it forces the per-element Transition contract
  # eagerly via deep_seq.
  StateMachine = std.contract.custom (fun _label value =>
    let transitions = value.transitions in
    let _conformance =
      std.array.fold_left
        (fun acc t => std.deep_seq (t | Transition) acc)
        null
        transitions
    in
    # Structural checks:
    # (a) every from/to label is non-empty (NonEmptyString is enforced via Transition)
    # (b) transition array is non-empty (a machine with no transitions is inert)
    let non_empty_transitions = std.array.length transitions > 0 in
    std.seq _conformance (
      if !non_empty_transitions
      then 'Error { message = "state machine has no transitions" }
      else 'Ok value
    )
  ),

  # ── The checked topology instance ────────────────────────────────────────────
  # This is what `nickel export` validates. Composing L0Transitions ++ L1Transitions
  # into one record lets `nickel export` gate both layers in a single command.
  #
  # Usage:
  #   nickel export -I ledger/contracts ledger/contracts/state_machine.ncl
  #
  # A reviewer reproduces the full topology check with that single command.
  topology = {
    description = "Predicate orchestrator state machine — Layer 0 (campaign) + Layer 1 (orchestration). Each transition's guard_contract names the existing artifact contract that must pass to exit the source state.",
    layers = {
      L0 = "campaign control loop (/campaign) — ABSORB→…→CLOSE; source: skills/campaign/SKILL.md",
      L1 = "runnable driver (/orchestrate) — DERIVE→…→CLOSE; source: skills/orchestration/SKILL.md",
    },
    transitions = L0Transitions @ L1Transitions,
  } | StateMachine,
}
