---
name: orient
description: |
  Project-orientation workflow (/orient): installs predicate's enforcement
  into a target project, maps its structure and goal, and authors the
  persistent conditioning layer (AGENTS.md goal-hierarchy) so every
  subsequent walk is anchored and gated.
  Trigger when:
  - Onboarding a new project into predicate for the first time.
  - Refreshing an existing project's AGENTS.md hierarchy against the
    current state of the repository (re-run = refresh).
  - Prompt contains: /orient, orient workflow, onboard project, project
    orientation, AGENTS.md hierarchy, persistent conditioning layer.
---

# Orient: Project Orientation Workflow

Predicate is **project-centric**: `/orient` is its first contact with a
project. It engages *this* repository concretely — installs predicate's
enforcement, maps the repo, learns its goal, and authors the **persistent
conditioning layer** (the AGENTS.md goal-hierarchy) so every subsequent
walk is anchored and gated. Not an idealized formula imposed from outside;
a boundary fitted to the actual project.

**Quickstart:** install predicate into your harness → target a project →
run `/orient`.

---

## Phases (state machine; halts at the two human seams)

The eight phases execute in order. Two are **human seams** — the walk
halts and awaits human input before continuing. The others are
mechanical or agent-automated.

### Phase 0 — BOUND *(compose `/boundary` — do not rush)*

Before touching the repo, invoke [`/boundary`](../boundary/SKILL.md) to
draft an IBC for the orientation work itself: what is this project, what
is known vs unknown going in, what is the desired end state of onboarding
it.

`/boundary` is also the **authority for the AGENTS.md contract** the
AUTHOR phase (phase 6) conforms to — composed here, not duplicated. The
required content (Goal, Requirements/Invariants/Constraints, Unknowns,
Operational entrypoint, Structure, Alignment-to-parent) and the soundness
invariants are defined in
[`/boundary §AGENTS.md`](../boundary/SKILL.md#agentsmd--the-project-scope-boundary).

### Phase 1 — ESTABLISH *(mechanical, automated — no human input)*

Run `bootstrap init`: install git hooks into `.git/hooks` (untracked,
auditable, removable), initialize the `.ledger` sub-repository, wire
project config. Idempotent — safe to re-run on an already-oriented
project.

### Phase 2 — MAP *(domain — outward→structure; cheapest tier; hunt-to-dry)*

Fan out a multi-modal sweep over the repository:

- **Structure** — `git ls-files` for the file tree; directory layout.
- **Semantics** — what each component does; package/module roles.
- **History** — `git log` shape; maturity signals; areas of churn.
- **Docs** — stated purpose in READMEs, existing AGENTS.md files, or
  architectural docs.

Scale to the repo: a small project needs one pass; a large one warrants
the full sweep. Stop when no new approach-relevant structure surfaces.
This phase carries no goal-fit judgment and routes to cheap agents.

### Phase 3 — SURVEY *(arsenal — outward→environment; cheapest tier)*

Enumerate predicate's own skills plus the host harness's installed
skills, tools, and MCP servers available to this project. Project each
for relevance to the discovered structure; do not enumerate exhaustively
into context.

### Phase 4 — ELICIT *(goal — HUMAN SEAM, halt)*

**This phase halts.** The walk does not proceed until the human confirms
the goal.

From the MAP, extract a candidate goal + requirements / invariants /
constraints / known-unknowns. Present the candidate to the human with:

- the extracted goal statement (desired end state, not status);
- the requirements, invariants, and constraints identified;
- the known-unknowns with signposts (what would resolve each);
- any conflicting signals in the docs or history that affect goal-fit.

**Halt and await confirmation.** Goal-fit is not self-attestable — an
agent is least calibrated exactly here; the human is the goal authority.
Do not proceed to NEST or AUTHOR until the goal is confirmed or corrected.

### Phase 5 — NEST *(structure decision)*

Decide which directories have a goal *genuinely distinct from and in
service of* the root goal, and therefore warrant their own AGENTS.md.

**Default: root only.** Add a component AGENTS.md only when a real
sub-goal exists. Every additional file is a staleness surface: it must be
kept true, linked correctly, and synced at every refresh. The
alignment-to-parent requirement (from the AGENTS.md contract) is the
defeater substrate — a component whose goal does not serve the root is
a structural fault.

### Phase 6 — AUTHOR *(draft against the contract — authority: `/boundary`)*

Draft the root AGENTS.md and any component files decided in NEST. Each
draft MUST conform to the AGENTS.md contract in
[`/boundary §AGENTS.md`](../boundary/SKILL.md#agentsmd--the-project-scope-boundary):

- **Self-contained entrypoint.** Every pointer resolves in-repo or
  carries a URL. No assumed external knowledge.
- **Goal = desired end state**, not a status report. Marked WIP where
  the end state is not yet reached.
- **Single source.** Reference authorities
  ([rules.md](../../rules.md), [ambient.md](../../ambient.md), specs);
  never copy their text.
- **Agent-guiding only.** If removing a line changes no agent action,
  cut it.
- **Unknowns are first-class**, treated like requirements, each with a
  signpost.
- **Minimal surface area.** Every line is a liability kept true;
  brevity is anti-drift.

Component AGENTS.md files MUST include the alignment-to-parent section
(how this component serves the root goal).

### Phase 7 — RECONCILE *(HUMAN SEAM — the sync gate)*

**This phase halts.** The persistent layer mutates only through this
reconciliation — never silently.

Present each draft AGENTS.md to the human. The human reconciles
(the volatile draft → persistent sync). On approval, land files at their
target paths (root `/AGENTS.md`; component `<dir>/AGENTS.md`).

**Unanswered questions** from the known-unknown registry that were not
resolved during ELICIT are re-presented here for prioritization, so a
topic-change does not lose them.

---

## Re-run = Refresh (anti-rot)

On an already-oriented project, `/orient` is the **sync/refresh** pass.
Run it whenever the AGENTS.md hierarchy may have drifted from reality.

The refresh pass re-executes the same eight phases but MAP and SURVEY are
diff-scoped (what changed since the last orientation). ELICIT surfaces
**drift candidates**: stale claims, dead links, a parent goal a child no
longer serves (a defeater), requirements that became constraints or vice
versa.

RECONCILE on a refresh presents only the changed sections, not the full
file. **Surfaced-but-unanswered known-unknowns from prior orientations
are re-presented** so they are never silently dropped.

---

## Tier Economy

| Phase | Tier | Rationale |
| :--- | :--- | :--- |
| 0 BOUND | Architect | Bounding judgment; goal-fit stakes highest here |
| 1 ESTABLISH | Mechanical | Pure bootstrap execution; no judgment |
| 2 MAP | Cheap agents | Structure survey; no goal-fit judgment |
| 3 SURVEY | Cheap agents | Enumeration and relevance projection |
| 4 ELICIT | Architect + Human | Goal-fit is not self-attestable; human seam |
| 5 NEST | Architect | Structural coupling judgment |
| 6 AUTHOR | Architect | Contract-conformant draft |
| 7 RECONCILE | Human | Persistent layer mutates only here |

---

## See Also

- [`/boundary`](../boundary/SKILL.md) — the authority for the IBC
  sufficiency conditions (phase 0) and the AGENTS.md contract (phase 6).
- [`/campaign`](../campaign/SKILL.md) — for multi-workstream orchestration
  after orientation is complete.
- [`rules.md`](../../rules.md) — the governing Prime Invariants every
  AGENTS.md references.
- [`ambient.md`](../../ambient.md) — the always-on principles the
  AGENTS.md hierarchy anchors to.
