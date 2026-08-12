# Gate-scope taxonomy — machine-legible source of truth.
#
# Declares EVERY gate in the predicate gate surface: each hook tier and each
# script in ledger/gate/, gates/, and the skill scripts they invoke.  The
# structural gate (ledger-validate.sh structure) export-validates this file on
# every commit that stages it, so an invalid scope string fails export.
#
# check_scopes.sh is the completeness checker: it enumerates the ACTUAL gate
# surface and exits non-zero if any gate is absent from this manifest.
#
# Gate identifiers use repo-root-relative paths for file-based gates, and the
# logical key "hook/<hook>:<tier>" for hook tiers.  check_scopes.sh matches on
# the same identifier space.
#
# Fields per gate entry:
#   gate        string identifier (repo-root-relative path or hook/<hook>:<tier>)
#   scope       one of: universal | predicate_artifact | campaign | walk |
#               project_local | recorder | orchestration
#   fires_when  activation condition in plain language
#   applies_to  "human + agent" or "agent only"
#
# Scope semantics
# ───────────────
#   universal          every commit, human or agent, IN THE PROJECT REPO
#   predicate_artifact every commit that stages a *.ncl or *.md file (structural tier)
#   campaign           iff .ledger/active-dag present (authority tier)
#   walk               iff .ledger/active-walk present (process tier)
#   project_local      every commit; runs the consuming project's own .ledger/gates/
#   recorder           every commit IN THE .ledger SUBREPO'S OWN git history — a
#                       DIFFERENT commit path from all scopes above, which govern
#                       the project repo. .ledger is its own git repository
#                       (ledger/README.md), so a commit made inside it is
#                       invisible to every project-repo hook; this scope is the
#                       recorder's own gate, installed into its own .git/hooks/.
#   orchestration      NOT on the commit path; run by orchestrator or CI

let Scope = [|
  'universal,
  'predicate_artifact,
  'campaign,
  'walk,
  'project_local,
  'recorder,
  'orchestration,
|] in

let GateEntry = {
  gate       | String,
  scope      | Scope,
  fires_when | String,
  applies_to | String,
} in

{
  gates = [

    # ── HOOK TIERS (hooks/commit-msg and hooks/pre-commit) ──────────────────

    {
      gate        = "hook/commit-msg:hygiene",
      scope       = 'universal,
      fires_when  = "every git commit; invokes skills/commit-hygiene/scripts/check_commit_msg.py (Conventional Commits form; merge: is a first-class type)",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "hook/commit-msg:selfcontained",
      scope       = 'universal,
      fires_when  = "every git commit; invokes gates/check_selfcontained.sh (rejects internal node-ID / layer-tag refs in message)",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "hook/pre-commit:orphans",
      scope       = 'predicate_artifact,
      fires_when  = "staged authoritative files; invokes gates/check_orphans.sh scoped to the staged set",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "hook/pre-commit:doc-links",
      scope       = 'predicate_artifact,
      fires_when  = "staged *.md files; invokes skills/doc-audit/scripts/check_docs.py for valid local links and anchors",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "hook/pre-commit:ledger-structure",
      scope       = 'predicate_artifact,
      fires_when  = "staged *.ncl files; invokes ledger/gate/ledger-validate.sh structure to ensure nickel export passes",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "hook/pre-commit:authority",
      scope       = 'campaign,
      fires_when  = "iff .ledger/active-dag is present; invokes ledger/gate/ledger-validate.sh authorize against the DAG file_surface",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "hook/pre-commit:process",
      scope       = 'walk,
      fires_when  = "iff .ledger/active-walk is present AND the declared deposit-path is staged; invokes ledger/gate/process-gate.sh validate",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "hook/pre-commit:project-local",
      scope       = 'project_local,
      fires_when  = "every commit; invokes ledger/gate/project-gates.sh which runs all executable scripts in <project-root>/.ledger/gates/ sorted by name; no-op when .ledger/gates/ is absent",
      applies_to  = "human + agent",
    } | GateEntry,

    # ── LEDGER/GATE SCRIPTS ──────────────────────────────────────────────────

    {
      gate        = "ledger/gate/ledger-validate.sh",
      scope       = 'predicate_artifact,
      fires_when  = "commit-time (structure sub-command) on staged *.ncl; orchestration (authorize / commit-gate) at dispatch",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "ledger/gate/authorized.py",
      scope       = 'campaign,
      fires_when  = "called by ledger-validate.sh authorize; decides whether each staged path falls under a DAG node file_surface",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/process-gate.sh",
      scope       = 'walk,
      fires_when  = "walk-activated (iff .ledger/active-walk present); validates procedure deposits against Nickel contracts at commit time",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/project-gates.sh",
      scope       = 'project_local,
      fires_when  = "every commit via hook/pre-commit:project-local; discovers and runs executable scripts in <project-root>/.ledger/gates/; no-op when directory is absent",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "ledger/gate/recorder-pre-commit.sh",
      scope       = 'recorder,
      fires_when  = "every commit made INSIDE a .ledger subrepo; validates staged tech-debt/*.yaml and process-feedback/*.yaml against their Nickel apply-contract shims; fails loudly (rc 2) if nickel is required but absent",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "ledger/gate/install-recorder-hook.sh",
      scope       = 'recorder,
      fires_when  = "installed by bootstrap/install.sh init (composed, never inlined); wires recorder-pre-commit.sh into <ledger>/.git/hooks/pre-commit, idempotently",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "ledger/gate/check_scopes.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-scope step and manual; verifies every gate in the actual surface is declared in scopes.ncl (fails on omission)",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/gate-set.sh",
      scope       = 'orchestration,
      fires_when  = "orchestrator or CI; proves /core gate set is a superset of the node gate set (scale-invariance check)",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/adherence_audit.sh",
      scope       = 'orchestration,
      fires_when  = "orchestrator at campaign CLOSE; audits worktree isolation via git merge history",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/coherence_impact.sh",
      scope       = 'orchestration,
      fires_when  = "orchestrator at each node landing (RECONCILE step); checks contracts, orphans, and links across the full tree",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/premise_fresh.sh",
      scope       = 'orchestration,
      fires_when  = "orchestrator before dispatching a pending node; re-runs S1 tripwires against HEAD to detect stale premises",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/recorder_close_check.sh",
      scope       = 'orchestration,
      fires_when  = "orchestrator at campaign CLOSE; asserts a 'log: close <topic>' commit exists in the flight recorder",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/tracker_fresh.sh",
      scope       = 'orchestration,
      fires_when  = "orchestrator or /orient; validates context-map last_validated timestamps against HEAD commit date",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/tracker_fresh.py",
      scope       = 'orchestration,
      fires_when  = "called by tracker_fresh.sh; effectful tier: exports the context-map and evaluates the Nickel freshness predicate",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_gates.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; exercises ledger-validate, authority overlay, doc-link, recorder, adherence, orphan, selfcontained, sync-sketch, and commit-msg gates from main tree and linked worktree",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_reconcile.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; exercises premise_fresh.sh and coherence_impact.sh with fixtures",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_surface_protocol.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; exercises authorized.py collision-check and reconcile-node protocols",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_adherence.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; exercises adherence_audit.sh with synthetic git histories",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_contract_typecheck.sh",
      scope       = 'orchestration,
      fires_when  = "CI contract-typecheck step; asserts every ledger/contracts/*.ncl typechecks cleanly",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_fixture_sweep.sh",
      scope       = 'orchestration,
      fires_when  = "CI fixture-polarity-sweep step; asserts every ledger/fixtures/*.ncl behaves per its declared polarity",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/demo_scale_invariant.sh",
      scope       = 'orchestration,
      fires_when  = "CI smoke and manual; runs the gate sequence under both a campaign DAG and a one-node DAG, asserts byte-identical transcripts",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/demo_unauthorized.sh",
      scope       = 'orchestration,
      fires_when  = "CI smoke and manual; stages an unauthorized path (expects non-zero), then confirms an authorized path passes",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_project_gates.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; exercises project-gates.sh runner (runner unit tests) and the hook tier-6 integration (standalone consuming-project repo)",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_recorder_hook.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; exercises recorder-pre-commit.sh (invalid/conformant records, nickel-absent) and install-recorder-hook.sh init/deinit wiring",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_conditioning_sweep.sh",
      scope       = 'orchestration,
      fires_when  = "CI conditioning-sweep step; asserts every conditioning/*.ncl behaves per its declared polarity, machine-guarding the HasCore injection-rule proof",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_conditioning_discipline.sh",
      scope       = 'orchestration,
      fires_when  = "CI conditioning-sweep step; materializes the install into a throwaway HOME and asserts the typed-claim grammar sits at the record-writing rungs and nowhere in the always-on core, alongside the minimality cut list's end state and the core-to-delta duplication ratchet",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/conditioning_probe.py",
      scope       = 'orchestration,
      fires_when  = "called by test_conditioning_discipline.sh; measurement engine over the materialized surfaces — proves the verbatim core region, counts a signature per scope, and shingles core-to-delta duplication",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_colocation_gate.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; verifies that bootstrap/install.sh init installs templates/project-gates/* into .ledger/gates/ and that the colocation gate fires when a skill-owned contract is re-centralized",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/check_grammar_home.py",
      scope       = 'orchestration,
      fires_when  = "CI grammar-home step; binds docs/entries.md (the vocabulary home) to extract_entries.py's MAPPED/RECOGNIZED sets — fails on a mapped token the home never names, and on a documented token the extractor rejects",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_grammar_home.sh",
      scope       = 'orchestration,
      fires_when  = "CI grammar-home step; mutation suite proving check_grammar_home.py fails in BOTH directions — a home stripped of a mapped token, an extractor grown a token, and a home naming a token nothing implements",
      applies_to  = "agent only",
    } | GateEntry,

    # ── TEMPLATES/PROJECT-GATES (tracked source; installed to .ledger/gates/ by init) ──

    {
      gate        = "templates/project-gates/10-skill-contract-colocation.sh",
      scope       = 'project_local,
      fires_when  = "installed to <project>/.ledger/gates/ by bootstrap/install.sh init; fires on every commit in predicate; fails if any of the 5 skill-owned contract names (boundary_procedure, refine_procedure, refine_output, state_machine, tracker_freshness) reappears in ledger/contracts/",
      applies_to  = "human + agent",
    } | GateEntry,

    # ── GATES/ SCRIPTS (invoked from hooks and orchestration) ────────────────

    {
      gate        = "gates/check_orphans.sh",
      scope       = 'predicate_artifact,
      fires_when  = "commit-time via hook/pre-commit:orphans; also standalone and from coherence_impact.sh",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "gates/check_selfcontained.sh",
      scope       = 'universal,
      fires_when  = "commit-time via hook/commit-msg:selfcontained; rejects messages with internal node-ID or layer-tag references",
      applies_to  = "human + agent",
    } | GateEntry,

    # ── SKILL SCRIPTS (invoked from hooks or CI) ─────────────────────────────

    {
      gate        = "skills/chronicle/scripts/update_chronicle.py",
      scope       = 'orchestration,
      fires_when  = "orchestrator or manual; regenerates docs/chronicle.md from skill SKILL.md headers and the skill routing table",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "skills/commit-hygiene/scripts/check_commit_msg.py",
      scope       = 'universal,
      fires_when  = "commit-time via hook/commit-msg:hygiene and CI; enforces Conventional Commits form (header length, type, blank line, body wrap), merge-exempt",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "skills/doc-audit/scripts/check_docs.py",
      scope       = 'predicate_artifact,
      fires_when  = "commit-time via hook/pre-commit:doc-links on staged *.md; also CI doc-audit step for the full tree",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "skills/refine/scripts/sync_sketch.py",
      scope       = 'orchestration,
      fires_when  = "orchestrator at reconciliation boundary; syncs .scratch/<topic>/ volatile draft into the .ledger/log/ flight recorder",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "skills/security-audit/scripts/run_audit.py",
      scope       = 'orchestration,
      fires_when  = "orchestrator or manual; runs the security-audit sweep and emits a findings deposit",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "skills/commit-hygiene/scripts/test_check_commit_msg.sh",
      scope       = 'orchestration,
      fires_when  = "orchestrator or CI; proves check_commit_msg.py accepts a merge: subject, rejects an over-length merge: header and a bare git merge subject, and still passes a conventional header",
      applies_to  = "agent only",
    } | GateEntry,
  ],
}
