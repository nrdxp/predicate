# AGENTS.md — Predicate

This repository **is** Predicate, the upstream. `skills/`, `rules.md`, and
`ambient.md` live at the root because other projects consume them as an installed
plugin — see [README.md](README.md) and
[docs/getting-started.md](docs/getting-started.md).

## Goal

Predicate is a self-hosting, harness-agnostic framework that **keeps AI coding
agents anchored to the true goal across long-horizon work.** It has two
synergistic halves:

- **Correction** — externalize correctness to the strongest evaluator (the
  **Verification Dual**: *verify, then trust* — no condition closed by an agent's
  say-so). Authority: [rules.md](rules.md).
- **Prevention** *(WIP)* — externalize the goal, requirements, unknowns, and
  available tools as a durable, selectively-projected **conditioning layer**, so a
  walk stays focused *before* drift compounds.

Correction without prevention corrects toward the wrong goal; prevention without
correction drifts anyway over a long horizon. Together they bound drift.

## Formal substrate

An LLM is an autoregressive stochastic walk over a token state-space; in
open-loop generation error compounds, so drift is a statistical inevitability
over long horizons. Predicate closes the loop — an external deterministic
evaluator computes an error differential and updates the boundary condition
toward a fixed point (ΔE → 0). The formalism is non-entropic: it is the anchor
the doctrine rests on, not the doctrine. Full treatment:
[docs/theory/formalism.md](docs/theory/formalism.md); lexicon in
[rules.md](rules.md) §1. *(WIP: extends to model attention-dilution and
design-space constriction as the conditioning layer lands.)*

## Requirements (for predicate to be useful)

- **Self-hosting** — predicate governs its own development.
- **Harness-agnostic** — every capability degrades to a harness-native primitive
  (`git` / `bash` / `python` / `nickel`); a harness convenience may accelerate a
  step but never replaces the primitive path when it is absent or fails.
- **Machine-checkable where possible** — artifacts *and process* are bound by
  evaluators (footprints), not by an agent's memory of the rules.
- **Composable** — co-exists with whatever other plugins / skills / MCP servers
  the host harness has installed.

## Invariants (soundness)

The six Prime Invariants, in precedence order, are authoritative in
[rules.md](rules.md) §2 — read the source, not a copy here: Verification Dual ·
Halt over assumption · Cutting Imperative · History is the deliverable ·
Reconstruct don't recall · Tier economy.

## Constraints (engineering)

- **Maturity: `molten`** (pre-1.0) — refactor and cut freely; design over
  stability ([README.md](README.md)).
- **Context economy** — every artifact is drift surface; cut what is not
  load-bearing.

## Building toward the goal (WIP — the prevention half)

The conditioning layer is in active design. Components:
- The contract + check for an effective AGENTS.md (this file is its first
  instance).
- A project **initialization workflow** that maps a repository and authors its
  AGENTS.md hierarchy.
- A **defeater register**: each load-bearing assumption carries an explicit
  invalidating condition + a monitored signpost ("did serving a sub-goal defeat
  its parent goal?").
- Nested AGENTS.md as the goal hierarchy (ecosystem ⊃ project ⊃ component), the
  substrate for projection and defeater checks.

## How to work in this repo

- Read [skills/constitution/SKILL.md](skills/constitution/SKILL.md) before
  starting.
- Documentation/skills repository; no build. Validate links with
  `python3 skills/doc-audit/scripts/check_docs.py .`. Every commit passes the
  Commit Gate ([rules.md](rules.md) §3).
- Consumed downstream as an installed plugin via `bootstrap/`, not a submodule or
  symlink.

## Structure — what is core vs context-sensitive

**Always-on substrate** (never not active): [rules.md](rules.md) (the Prime
Invariants), [ambient.md](ambient.md) (standing principles),
[skills/constitution/SKILL.md](skills/constitution/SKILL.md) (authority
hierarchy), and the Commit Gate ([rules.md](rules.md) §3).

**The `boundary → campaign` spine** — predicate's coordination process; full
detail in [README.md](README.md). On top, the tier-aware workflows: `/boundary`
(the IBC contract) and `/campaign` with its deterministic driver `/orchestration`
(architect survey → orchestrate → reconcile). Below, the single-walk workflows
invoked by moment: `/core`, `/refine`, `/form`, `/doc`, `/chronicle`.

**Enforcement machinery** (intrinsic, not skills): [ledger/](ledger/) (Nickel
contracts that make campaign artifacts machine-valid), [gates/](gates/)
(referential-truth and self-containment checks), [hooks/](hooks/) (the commit
gate). The Verification Dual's symbolic path is machinery, not an agent's memory.

**Context-sensitive arsenal** (invoked by moment, per task): the language skills
(`go`, `rust`, `python`, `typescript`, `quarto`), the audit skills
(`security-audit`, `api-audit`, `ai-audit`, `git-review`, `doc-audit`), the
analysis lenses (`hickey`, `lowy`, `sdma`, `spec`, `formal-foundations`), and
`prior-art`. Routing table: [rules.md](rules.md) §5. The host harness's *other*
installed skills, tools, and MCP servers extend this arsenal — at the start of
non-trivial work, survey for a capability that would change the approach; do not
enumerate.

## Version

Pre-1.0 (`molten`): breaking changes expected.
