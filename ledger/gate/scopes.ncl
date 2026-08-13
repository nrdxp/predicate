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
      gate        = "ledger/gate/trial_merge.sh",
      scope       = 'orchestration,
      fires_when  = "composer or orchestrator, before the real `git merge` of a node or campaign branch into master; trial-merges the branch into a throwaway clone and runs the merged tree's full test_*.sh battery, failing on any cross-branch regression a per-branch gate cannot see (deferred-queue [D79]-[D81]). Not CI-wired: CI's pull_request trigger already checks out GitHub's merge ref post-hoc, but this project's composer merges locally via git CLI before a forge ever sees the branch (constitution: forge observes, never gates), so the pre-merge window this closes has no push/PR event to hang a CI step on",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_trial_merge.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; fixture suite for trial_merge.sh — a cross-branch regression on disjoint files with a clean merge (the D79-81 fixture), a clean merge staying green, a conflict reported distinctly from a battery failure, a pre-existing branch failure carried forward rather than blamed on the merge, and a real invocation against this repo's own master leaving git status, worktree list, and refs/heads byte-identical",
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
      gate        = "ledger/gate/test_candidate_links.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; exercises ledger/derive/candidate_links.py as a standalone computation (co-citation and stem/title-overlap candidate surfacing over the corpus, structural-value assertions against its JSON export, a mutation-can-fail demonstration) — never a non-zero exit; consumed by the harness SessionStart hook, not by any git hook",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_session_start.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; exercises harness/session_start.py (the Claude Code SessionStart hook) — recent-activity co-citation, branch-name overlap as the cold-start cover, absent/empty .ledger, malformed stdin, a non-git cwd, budget truncation with an honest dropped-count, structural-value assertions against the Surface dataclass, and a mutation-can-fail demonstration — never a non-zero exit",
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
      gate        = "ledger/gate/test_report_fraction.sh",
      scope       = 'orchestration,
      fires_when  = "CI conditioning-sweep step; materializes the install into a throwaway HOME and asserts the always-on law obliges every walk to REPORT ITS UNCLOSED FRACTION — stated rather than merely computable, naming the denominator and the body of work it ranges over, at one rung and with the query mechanism kept out of the law",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_scrutiny_allocation.sh",
      scope       = 'orchestration,
      fires_when  = "CI conditioning-sweep step; materializes the install into a throwaway HOME and asserts the always-on law ALLOCATES SCRUTINY BY STAKES AND UNCLOSEABILITY rather than uniformly — binding at authoring rather than only at review, giving the top rank a named procedure rather than an intensity, and calling out the claim whose author is also the party who will satisfy it",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_open_surface.sh",
      scope       = 'orchestration,
      fires_when  = "CI conditioning-sweep step; materializes the install into a throwaway HOME and asserts the always-on law governs the record's OPEN SURFACE on both faces at once — an unbacked claim is debt that moves toward an answerable question, an answer or removal and is never true merely because it is written down, and that same surface is a resource consulted BEFORE new derivation rather than only at review — with the two faces stated together as one rule",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_record_first.sh",
      scope       = 'orchestration,
      fires_when  = "CI conditioning-sweep step; materializes the install into a throwaway HOME and asserts the COMPOSER PERSONA rung — not the always-on law — carries the record-first ordering WITH its ground: conversational output bounded on the stated occasion of the head approaching conversationally, head-facing output named as drift potential, the conductor's coherence named as upstream of the walks it dispatches, all stated with the ordering rather than apart from it, and present in the composer surface while absent from core and from every dispatched-role delta",
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

    {
      gate        = "ledger/gate/test_corpus_ids.sh",
      scope       = 'orchestration,
      fires_when  = "CI corpus-ids step; multi-document fixture corpora pinning reference resolution ACROSS documents — a qualified [stem:ID] resolves corpus-wide, a plain [ID] stays doc-local with no fallback, a wikilink stays external even where its text reads as a corpus id, and an unresolvable qualified id is reported rather than filed as external provenance",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/council_consent.sh",
      scope       = 'orchestration,
      fires_when  = "orchestrator before any git merge (MERGE state); asserts every 'merge decision in the decision-ledger YAML carries the lead maintainer's recorded assent, by exporting the ledger through council_apply.ncl's merge-consent guard; also exercised by test_council_smoke.sh",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_context_map.sh",
      scope       = 'orchestration,
      fires_when  = "nickel fixture suite for context_map.ncl (the live requirement/invariant/unknown tracker) via context_map_apply.ncl, including a tracker_fresh.sh pass over the hydrated fixture; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_council.sh",
      scope       = 'orchestration,
      fires_when  = "nickel fixture suite for council.ncl (the constitution and decision-ledger law) via council_apply.ncl; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_council_smoke.sh",
      scope       = 'orchestration,
      fires_when  = "end-to-end composition smoke test proving council.ncl, council_consent.sh, and the ledger/fixtures/council/*.yaml decision-ledger instances agree over the SAME instances; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_deposit.sh",
      scope       = 'orchestration,
      fires_when  = "nickel fixture suite for deposit.ncl (the P-GROUND deposit substrate) via deposit_apply.ncl; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_anchored_surface.sh",
      scope       = 'orchestration,
      fires_when  = "suite for the anchored-reachability open-surface primitive (ledger/derive/anchored_surface.sh): binds two-hop traversal across backed transit nodes, rendered ordering for a known anchor, the ranker selector, budget truncation and path-invariance of the rendered floor; run manually by a dev/agent - not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_entries_extract.sh",
      scope       = 'orchestration,
      fires_when  = "golden-vector suite for the typed-claim extractor (ledger/derive/extract_entries.py) and entries_query.ncl: proves --census reproduces each fixture's self-published token count and that extraction output passes entry_apply.ncl; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_entry.sh",
      scope       = 'orchestration,
      fires_when  = "nickel fixture suite for entry.ncl (the ledger typed-claim entry shape) via entry_apply.ncl; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_findings.sh",
      scope       = 'orchestration,
      fires_when  = "nickel fixture suite for findings.ncl (the findings ledger) via findings_apply.ncl; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_process_feedback.sh",
      scope       = 'orchestration,
      fires_when  = "nickel fixture suite for skills/record/process_feedback.ncl via its apply shim (the same path the PROCESS gate uses at commit time); run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_reconcile_log.sh",
      scope       = 'orchestration,
      fires_when  = "nickel fixture suite for reconcile_log.ncl via reconcile_apply.ncl — distinct from test_reconcile.sh, which exercises premise_fresh.sh/coherence_impact.sh rather than this contract; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_refine_output.sh",
      scope       = 'orchestration,
      fires_when  = "nickel fixture suite for skills/refine/refine_output.ncl (RefineReport + RefineOutput: maintainer/auditor vouches, fixed-point-hash monotonicity, the unanimity gate) via refine_output_apply.ncl; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_tech_debt.sh",
      scope       = 'orchestration,
      fires_when  = "nickel fixture suite for skills/record/tech_debt.ncl via its apply shim (the same path the PROCESS gate uses at commit time); run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_worker_ibc.sh",
      scope       = 'orchestration,
      fires_when  = "nickel fixture suite for worker_ibc.ncl (the boundary contract: closed premises, routable unknowns, provenance-carrying Directives) via worker_ibc_apply.ncl; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_convergence.sh",
      scope       = 'orchestration,
      fires_when  = "CI convergence step; fixture corpora over ledger/derive/convergence.py pinning the UNDEFINED-vs-zero rate split (a direction with no terminal questions), partial and full discharge counts, closure by supersedes as well as discharges, corpus-wide counts independent of any direction, a hyphen-vs-underscore malformed terminal-question marker reported rather than silently dropped from its denominator, an empty direction register reported rather than a silent empty pass, and the no-args/unreadable-corpus CLI convention",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/self_vouch.py",
      scope       = 'orchestration,
      fires_when  = "run manually by a dev/agent against the main tree's .ledger (directions:D3-T8); not CI-wired because .ledger is gitignored project state absent from every CI checkout, so a live run there has no corpus to read — the same reason recorder_close_check.sh is not a CI step either. Derives, for every directions-stem terminal target, whether any CORROBORATED satisfaction naming it in `discharges` is witnessed by the same party as its own document's declared signer; reports self-witnessed vouched/unclosed claims for visibility without counting them, and reports an unmet target as unmet rather than a violation",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_self_vouch.sh",
      scope       = 'orchestration,
      fires_when  = "CI self-vouch step; synthetic fixture corpora over ledger/gate/self_vouch.py pinning a corroborated self-witnessed satisfaction as a violation (non-zero exit, named), a vouched self-witnessed claim on the same target reported but not counted, a target with no discharging claim at all reported unmet rather than a violation, an ordinary satisfaction witnessed by a different party staying clean, and the nonexistent-corpus usage/environment error",
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

    {
      gate        = "gates/check_forge_prose.sh",
      scope       = 'orchestration,
      fires_when  = "composer runs manually over every drafted PR/issue/comment body before posting (forge §2: drafting exists to enable this check); also exercised via ledger/gate/test_gates.sh (a CI gate-test step)",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "gates/check_internal_ids.sh",
      scope       = 'orchestration,
      fires_when  = "orchestrator at campaign CLOSE (whole-campaign ID-leak sweep over every line the campaign added) and manually in a node worker's worktree; also exercised via ledger/gate/test_gates.sh (a CI gate-test step)",
      applies_to  = "agent only",
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
