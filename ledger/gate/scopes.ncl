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
      gate        = "ledger/gate/clause_backing.py",
      scope       = 'orchestration,
      fires_when  = "derives each always-on-law clause's backing from its own declaration: resolves the named gate case against that gate's live source, proves the check holds against the rendered law and stops holding once the clause's text is removed, and errors on a declaration naming a missing gate or one whose check survives the clause it claims to guard; run manually by a dev/agent and exercised by test_clause_backing.sh",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_clause_backing.sh",
      scope       = 'orchestration,
      fires_when  = "CI clause-backing step; fixture suite for clause_backing.py pinning that a declaration naming a nonexistent gate is caught and that a decorative pattern - one surviving removal of the clause it claims to guard - is caught",
      applies_to  = "agent only",
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
      gate        = "ledger/gate/red_baseline.py",
      scope       = 'orchestration,
      fires_when  = "composer or orchestrator, at a node's RECONCILE step before the real `git merge` into master (directions:D3-T9, second half) — inspects a node branch's commit order between merge-base and tip for a `test:` commit preceding the `feat:`/`fix:` commit(s) it verifies, by Conventional-Commit type prefix (order only, never diff content); also runnable manually with --sweep over a revision range for a whole-campaign measurement. Not CI-wired for the same reason trial_merge.sh is not: node branches are local and are gated by the composer before a forge ever sees them, and a CI checkout is typically shallow and post-hoc to that window",
      applies_to  = "human + agent",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_red_baseline.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; fixture suite for red_baseline.py — a test: commit preceding an implementation commit (pass), an implementation commit with no preceding test: (fail, named), an implementation commit whose only test: commit lands after it (fail, distinct wording from no-evaluator-at-all), no implementation commit at all (pass, not a violation), an unparseable commit preceding the implementation with no earlier test: (ambiguous, never silently passed), a merge commit inside the range never counting as evaluator signal, --sweep aggregation across multiple merges including an octopus merge reported skip, usage/environment errors, and a mutation demonstration that breaks the ordering comparison and shows a fail fixture read as pass",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_install_hooks.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; fixture suite for hooks/install-hooks.sh's hooks-SOURCE resolution — a linked worktree of the self-hosted repo sources the main worktree's hooks/ rather than its own checked-out copy, the main worktree itself is unaffected, a consuming repo (installer's own repo differs from the repo being gated) is unaffected regardless of worktree topology, and --uninstall never removes a real (non-symlink) hook file for either managed hook name",
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
      gate        = "ledger/gate/test_pretooluse_agent_shadow.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; exercises harness/pretooluse_agent_shadow.py (the shadow-mode PreToolUse hook on Agent/Task dispatch, node/shadow-hook) and its registration in harness/hooks.json — a complete dispatch reporting every discriminating check true, a malformed dispatch reporting would_deny_if_enforced=true while STILL emitting bare {} and exit 0 (the load-bearing never-deny property), crash safety across missing/malformed/non-string/huge/unicode input, per-element discrimination (each of workspace/branch/base-commit/sanction/cited-sources flips independently on omission), seat-role detection and seating-declaration discrimination, JSONL logging with truncated/redacted prompt and description heads, hooks.json's PreToolUse registration, and matcher exclusion of SendMessage and the Task-family tools (TaskCreate/TaskUpdate/TaskGet/TaskList/TaskStop) per code.claude.com/docs/en/hooks' exact-string-alternation semantics, plus six mutation demonstrations (never-deny, one discrimination check, seat detection, log truncation, crash-safety except-narrowing, matcher exclusion) proving each corresponding assertion can fail",
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
      fires_when  = "CI gate-test step; nickel fixture suite for context_map.ncl (the live requirement/invariant/unknown tracker) via context_map_apply.ncl, including a tracker_fresh.sh pass over the hydrated fixture",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_council.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; nickel fixture suite for council.ncl (the constitution and decision-ledger law) via council_apply.ncl",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_council_smoke.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; end-to-end composition smoke test proving council.ncl, council_consent.sh, and the ledger/fixtures/council/*.yaml decision-ledger instances agree over the SAME instances",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_deposit.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; nickel fixture suite for deposit.ncl (the P-GROUND deposit substrate) via deposit_apply.ncl",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_anchored_surface.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; suite for the anchored-reachability open-surface primitive (ledger/derive/anchored_surface.sh): binds two-hop traversal across backed transit nodes, rendered ordering for a known anchor, the ranker selector, budget truncation and path-invariance of the rendered floor; its informational real-corpus section (C3) skips gracefully when no .ledger subrepo is present, as in every CI checkout",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_entries_extract.sh",
      scope       = 'orchestration,
      fires_when  = "golden-vector suite for the typed-claim extractor (ledger/derive/extract_entries.py) and entries_query.ncl: proves --census reproduces each fixture's self-published token count and that extraction output passes entry_apply.ncl; run manually by a dev/agent — not currently wired into ci.yml",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_walkthrough.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; pins ledger/examples/walkthrough/README.md's own claim that its commands and printed outputs are real: runs the extractor, entries_query.ncl, and convergence.py exactly as documented and asserts the documented counts/views/percentages, plus both refused/ demonstrations",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_entry.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; nickel fixture suite for entry.ncl (the ledger typed-claim entry shape) via entry_apply.ncl",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_findings.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; nickel fixture suite for findings.ncl (the findings ledger) via findings_apply.ncl",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_process_feedback.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; nickel fixture suite for skills/record/process_feedback.ncl via its apply shim (the same path the PROCESS gate uses at commit time)",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_reconcile_log.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; nickel fixture suite for reconcile_log.ncl via reconcile_apply.ncl — distinct from test_reconcile.sh, which exercises premise_fresh.sh/coherence_impact.sh rather than this contract",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_refine_output.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; nickel fixture suite for skills/refine/refine_output.ncl (RefineReport + RefineOutput: maintainer/auditor vouches, fixed-point-hash monotonicity, the unanimity gate) via refine_output_apply.ncl",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_tech_debt.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; nickel fixture suite for skills/record/tech_debt.ncl via its apply shim (the same path the PROCESS gate uses at commit time)",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_worker_ibc.sh",
      scope       = 'orchestration,
      fires_when  = "CI gate-test step; nickel fixture suite for worker_ibc.ncl (the boundary contract: closed premises, routable unknowns, provenance-carrying Directives) via worker_ibc_apply.ncl",
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

    {
      gate        = "ledger/gate/terminal_freshness.py",
      scope       = 'orchestration,
      fires_when  = "run manually by a dev/agent against the main tree's .ledger (directions:D3-T10); not CI-wired because .ledger is gitignored project state absent from every CI checkout, so a live run there has no corpus to read — the same reason self_vouch.py and recorder_close_check.sh are not CI steps either. Derives, for every directions-stem terminal target's satisfying claim, whether it carries axes:: at all and, where non-monotone, a freshness:: cure; reports an unmet target as unmet rather than a violation, and states plainly that it can confirm the coordinates were DECLARED, never that they are correct or that a named freshness mechanism has ever been re-run",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_terminal_freshness.sh",
      scope       = 'orchestration,
      fires_when  = "CI terminal-freshness step; synthetic fixture corpora over ledger/gate/terminal_freshness.py pinning a satisfying claim with no axes:: at all as a violation (non-zero exit, named), a non-monotone satisfying claim with no freshness:: cure as a violation, a monotone satisfying claim with no freshness owing nothing (clean), a target with no discharging claim at all reported unmet rather than a violation, an ordinary non-monotone satisfaction naming its cure staying clean, and the nonexistent-corpus usage/environment error",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/directions_register.py",
      scope       = 'orchestration,
      fires_when  = "run manually by a dev/agent against the main tree's .ledger (or an explicit corpus argument) — not CI-wired because .ledger is gitignored project state absent from every CI checkout, the same reason self_vouch.py and terminal_freshness.py are not. Closes the gate half of tech-debt/directions-half-conditioned.yaml under the head's AI5 ruling (whole-corpus form, never per-claim attribution — [DX1] stands): a corpus holding graded claims (assertion == \"claim\") with an absent or empty directions register is an error, and a direction carrying zero terminal questions is an error",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_directions_register.sh",
      scope       = 'orchestration,
      fires_when  = "CI directions-register step; fixture suite for directions_register.py over synthetic standalone corpora (empty register, no terminal targets, clean, claims-free questions-only) pinning AI5's two conditions and that a corpus holding only questions owes no register",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/entries_integrity.sh",
      scope       = 'orchestration,
      fires_when  = "run manually by a dev/agent over one or more explicit corpus paths — not currently wired into ci.yml; formalizes the extract-then-apply-contract invocation into one reusable whole-corpus entry-law gate (tech-debt/direction-id-reused.yaml): reports a qualified reference the extractor itself could not place, or anything EntryStore's own corpus-level checks refuse (a reused target id, or an unresolved discharges/supersedes edge), deferring to the full entry_apply.ncl contract rather than narrowing to only those two conditions",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_dependents_query.sh",
      scope       = 'orchestration,
      fires_when  = "run manually by a dev/agent — not currently wired into ci.yml; fixture suite for entries_query.ncl's dependents_of view, proving the reverse walk is transitive rather than one-level, terminates on a cycle without a node reporting itself as its own dependent, and stays inside the cost cap chain_floor's own generated-fixture guard uses",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_entries_integrity.sh",
      scope       = 'orchestration,
      fires_when  = "run manually by a dev/agent — not currently wired into ci.yml; fixture suite for entries_integrity.sh proving the wrapper correctly invokes the extractor and the contract and correctly propagates their verdict as its own exit code, reusing test_entries_extract.sh's and test_corpus_ids.sh's existing fixtures rather than re-authoring them",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/topic_query.sh",
      scope       = 'orchestration,
      fires_when  = "run manually by a dev/agent over an explicit view and one or more corpus paths — not currently wired into ci.yml; formalizes the ad hoc extract-then-query invocation seats have run by hand (tech-debt/close-answered-questions-unconditioned.yaml) into one reusable command over entries_query.ncl's exported views (awaiting_human | runnable_now | unpaid_cures | unbacked | chain_floor | untagged); scope composition is the caller's, never inferred from directory layout",
      applies_to  = "agent only",
    } | GateEntry,

    {
      gate        = "ledger/gate/test_topic_query.sh",
      scope       = 'orchestration,
      fires_when  = "run manually by a dev/agent — not currently wired into ci.yml; fixture suite for topic_query.sh proving a cross-document discharge carrier closes a question only when both the question's own document and the carrier's are in the query scope, with nothing about either document changing between the open and closed invocations",
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
