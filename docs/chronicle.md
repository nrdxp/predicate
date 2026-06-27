---
latest_commit: d1ddd81e5590c0d0a8d1568cc80dfe4560c26647
updated_at: 2026-06-27T17:40:00.000000
---
# Project Chronicle

This document tracks the conceptual evolution of the project.


## [2026-06-12] Commits: Inception..5abd08ce

- **Architectural Shift / Design Decisions**: Restructured the repository layout, moving flat rulesets under `axioms/` and `personas/`. Integrated the Structured Domain Modeling Architecture (SDMA) and added Quarto authoring rules.
- **Workflow & Rulesets**: Formalized key agentic workflows: `/predicate` (context refresh), `/continue` (invariant reinforcement), `/core` (execution state machine), `/sketch` (exploration), and `/plan` (design plans and challenges). Mandated TDD validation loops and `JUSTIFICATION` blocks at commit gates.
- **Features & Implementation**: Added comprehensive audit protocols: `api-audit` (API surface coherence), `security-audit` (web, web3, embedded security fragments), and `humanizer` (writing style cleanup).
- **Documentation**: Simplified AGENTS.md template, reorganized setup/submodule documentation, and created ADR-001 for the two-tier ruleset architecture.

## [2026-06-12] Commits: 5abd08ce..d1950aa6

- **Architectural Shift / Design Decisions**: Shifted `formal-foundations` from axioms to personas and consolidated redundant rule definitions to increase ruleset signal density.
- **Workflow & Rulesets**:
  - Introduced the `/doc` workflow for structured documentation alongside a `documentation` writing axiom.
  - Added the `/model` workflow for dual-mode formal domain modeling (applying category theory, coalgebra, etc.).
  - Added `/plan-review` for post-execution retrospect.
  - Hardened the `/core` workflow with adversarial self-review, a zoom-in philosophy, and an `ABORT` state.
- **Language & Modeling Personas**: Expanded the `typescript` and `python` language personas with deep idiomatic guidelines, and defined the SDMA persona.
- **Documentation**: Formulated `docs/authoring.md` for creating custom components, split setup guides into `docs/getting-started.md`, and added a Retrospective section to `PLAN.md`.

## [2026-06-12] Commits: d1950aa6..b23bcb11

- **Architectural Shift / Design Decisions**:
  - Re-architected rulesets (axioms/personas) and workflows into a single unified directory layout: `skills/<skill-name>/SKILL.md`.
  - Added `rules.md` containing the master global ruleset for Closed-Loop Stochastic Trajectory Control (C-LTC).
  - Introduced `plugin.json` to standardize the package definition for Predicate.
- **Workflow & Rulesets**:
  - Separated `commit-hygiene` into a standalone skill with its own format checks.
  - Hardened the `/core` and `/continue` workflows with Closed-Loop Trajectory Control dynamics, linking validation error feedback directly to prompt refinement.
  - Equipped `/sketch` with a Dynamic Sketchpad ledger for goal, constraint, and unknown tracking.
  - Aligned all workflow skills to the sequence formalism vocabulary and added a universal convergence bias principle in `rules.md`.
- **Documentation**: Expanded the setup, authoring, and verification guides in `docs/getting-started.md` to reflect modular plugins.

## [2026-06-12] Commits: b23bcb11..f90ea94f

- **Architectural Shift / Design Decisions**:
  - Mandated relative links in documentation and banned absolute paths.
  - Introduced `formalism.md` specifying the mathematical and control-theoretic foundations of Predicate.
  - Integrated Git worktree isolation and subagent isolation to prevent parallel workspace contamination.
- **Workflow & Rulesets**:
  - Created the `robust-testing` skill defining property-based and metamorphic test methods.
  - Designed the `/refine` workflow (and helper `sync_sketch.py`) for automated codebase optimization sweeps, incorporating Socratic checks, sieving/cutting filters, and oscillation tracking.
  - Formulated ADR-002: Multi-Boundary Subagent Sweeps to support concurrent refinement sweeps.
  - Hardened `commit-hygiene` to forbid contextless references (e.g., uncommitted task IDs) and require strict atomic boundary discipline.
- **Documentation**: Refactored the README to strip out verbose AI patterns and humanize structural prose.

## [2026-06-12] Commits: f90ea94f..b840f3a0

- **Architectural Shift / Design Decisions**:
  - Renamed the `model` skill to `form` to prevent namespace collisions.
  - Reorganized `rules.md` into ruleset v2.0, condensing core constraints to improve signal density.
  - Git-ignored the `.scratch/` directory for campaign workspaces.
- **Workflow & Rulesets**:
  - Added Hostile Maintainer review protocols and the Refine/Review Dialectic in the `/refine` workflow.
  - Created the `/boundary` skill (and `IBC.md` template) to define normative contract parameters.
  - Created the `/campaign` skill to coordinate multi-tier model operations (architect survey, worker routing).
  - Formalized cap-dependent Walker Economics in `rules.md`.
  - Built the `check_commit_msg.py` validator script to enforce Conventional Commits rules in the `commit-hygiene` checkpoint.

## [2026-06-19] Commits: b840f3a0..2eebd8b0

- **Architectural Shift / Design Decisions**: Refactored the historically-grown skill set into one cohesive, machine-checkable system organized around a single core invariant. Adopted the **Verification Dual** — every condition is closed by the strongest applicable evaluator on exactly one of two paths (a deterministic symbolic gate where one can exist, decorrelated context-free adversarial review where none can), both iterating to a fixed point. Added the **Cutting Imperative** as a Prime Invariant, governed by a `molten`/`stable` maturity flag, recasting unjustified artifacts as drift surface to be cut rather than amended-around. Introduced the **`boundary → campaign` spine** with single-walk disciplines beneath it, and an **ambient layer** (`ambient.md`) for standing principles that have no entrypoint. Recorded the doctrine and consolidation rationale in ADR-003.
- **Workflow & Rulesets**: Rewrote `rules.md` so the Verification Dual leads the Prime Invariants and the ledger gate is wired into the Commit Gate. Consolidated the skill set against the Dual: demoted four principle-shaped workflows (`sketch`, `dialectic`, `planning`, `predicate`) and the binding code-edit and robust-testing constraints into the ambient layer; cut five subsumed workflows (`plan`, `charter`, `plan-review`, `continue`, `personalization`); thinned `engineering` and folded `doc-audit`'s prose rules into `documentation`. Grounded `/core` refinement as a contraction loop.
- **Features & Implementation**: Built the Nickel **ledger** — intrinsic contracts for the campaign IBC, worker IBC, DAG (acyclicity, referential integrity, concurrent-surface conflict detection), findings, and reconcile log, each making "a condition is only closed once its evaluator is named" structurally unforgeable. Added a portable ledger-validation gate, a Kahn-layering derivation computed from the DAG, and a scale-invariant gate-set check.
- **Infrastructure & Quality**: Aligned `.gitignore` to the `.scratch/` mount, removed a dangling `.agent/workflows` symlink, and dropped a stale pipeline-augmentation plan.
- **Documentation**: Initialized the project chronicle and added the chronicle skill; documented the ledger substrate and its gates; absorbed README framing and planning-phase prose; neutralized references to the demoted and cut workflows across surviving skills, templates, and guides.

## [2026-06-19] Commits: 2eebd8b0..9f67eecf

- **Architectural Shift / Design Decisions**: Extended the cohesion refactor from a *mapped* campaign to a *self-driving* one by specifying the execution layer deterministically. Made the campaign's previously-implicit drift checks explicit: a per-boundary premise-freshness pass (re-verify every pending node against the new HEAD) and a bidirectional coherence-impact check, so cross-node drift dies at each reconcile boundary instead of accumulating to CLOSE. Reframed declared file surfaces as fail-closed authorization with an explicit surface-exceed protocol (halt → derive → collision-check → widen or serialize).
- **Workflow & Rulesets**: Added the machine-executable **orchestration protocol** (`docs/orchestration-protocol.md`) — the exact deterministic procedure that drives a validated campaign DAG to a correctly-merged branch, identical whether a human, an agent, or an external tool runs it, with the irreducible human role isolated to a small set of explicit `[HUMAN SEAM]` points. Made the campaign skill's drift gates explicit to match.
- **Features & Implementation**: Promoted the gate bundle into the repository as tracked, installable, un-bypassable machinery: standalone `gates/` (the semantic orphan gate and the self-containment gate) and `hooks/` (`commit-msg` + `pre-commit`) wired by an idempotent, worktree-aware `install-hooks.sh`, so a failing check blocks the commit rather than relying on recall. Hardened the DAG contract to enforce per-node discipline and surface overlap, and added the boundary reconcile evaluators (surface authorization, coherence-impact, premise-freshness) with fixtures and protocol tests.
- **Documentation**: Refreshed the durable docs to the current architecture. The README now leads with the Verification Dual, documents the ambient layer, the spine, the ledger/gates/hooks enforcement machinery, and the orchestration protocol, and includes them in the repository-structure diagram. Documented hook installation in the getting-started guide, fixed a residual cut-workflow example in the authoring guide, and recorded the doctrine and consolidation decision in ADR-003.

## [2026-06-27] Commits: 9f67eecf..d1ddd81e

- **Architectural Shift / Design Decisions**: Gave the Nickel conditioning system a composable **module/class layer**: prompt composition went from `core ++ persona` to `core ++ join(modules) ++ role_delta`, so a persona is now core plus a named bundle of middle-layer modules plus a thin role delta. This materializes the Verification Dual's **adversarial path** as a standing arsenal — decorrelated, read-only review personas dispatchable as agent-types, symmetric to the producer personas. A new ADR supersedes ADR-002's "fixed-personae" rejection, which the Verification Dual doctrine (now in core) overturns. The driving principle was minimal representation: because `HasCore` forces every persona to carry core verbatim, the only way a reviewer can shed inapplicable producer procedure is for that procedure not to live in core — so the surgical re-slice below is *entailed*, not optional.
- **Workflow & Rulesets**: Re-sliced the action **procedure** (TDD-first, one-shot skepticism, trajectory-freeze, root-cause) out of `core.ncl` into a per-role **`producer` module** pulled only by code-writers (core/refine/architect/form/spec); the judge-against-standards **rubric** stays in core. Doc- and boundary-workers intentionally shed the producer procedure (they do not write code) — a reviewed, intended delta, not a regression. No worker "class" was extracted: with the procedure centralized there was no delta duplication left to DRY. Added the **reviewer-class module** — a read-only spine with a finding contract that routes each finding by `class` (`correctness` vs `taste`), a structural dispatch contract (a reviewer receives only the artifact-by-reference and its lens; no prompter narrative crosses the boundary), and refute-by-default. Primed new always-on doctrine in core: **R-stability** (every walk is one walker on a human+machine team whose shared attractor is stability, fusing the nested task⊂component⊂project⊂ecosystem basins into one convergence — an expedient hack is globally a miss, hence a defeater); **R-veto** (reviewer findings are advisory inputs to a context-saturated judge, who keeps a grounded veto on correctness); and **R-taste** (the human arbitrates taste via three tiers — provable/settled → architect authority, strong consensus → adopt-by-default, discriminating fork → surfaced directly to the human; the bound is transparency, not abstention).
- **Features & Implementation**: Added `HasModule`/`HasLens` substring-contract siblings to `HasCore`. Built the lens-free **refuter** (`core ++ reviewer_class`, with sweep-vs-refuter falling out of composition rather than a mode flag) plus **eight decorrelated lens personas** — vestigial (net-new, no owning skill — it hunts drift residue), ai-slop, hickey, lowy, api, security, git-review, and prior-art (the only lens with outward access, grounding by citation). Wired all nine `predicate-*-reviewer` agent-types live across `plugin.json`, `marketplace.json`, the conditioning installer, and the arsenal registry; 16 roles compose, the conditioning e2e suite passes (96 cases), and the seven pre-existing personas render byte-for-content unchanged.
- **Documentation**: Refreshed the composition-law docs after the re-slice (compose comments, the ARCHITECTURE snapshot and composition-law section, the craft-guide law). Notably, the fleet **reviewed itself at CLOSE**: the new vestigial and refuter lenses, run over the campaign's own diff, caught doc-staleness breadcrumbs left by the re-slice, which a follow-up cleanup node removed. The branch's commits are unsigned pending a re-sign (the hardware key was offline during the campaign).
