---
name: forge
description: |
  Conditional discipline for projects hosted on a git forge (GitHub,
  GitLab, Forgejo, …): branch↔PR mapping, self-contained PR prose,
  review-on-forge, merge consent, and the forge audit.
  Trigger when:
  - Opening, updating, reviewing, or merging a pull/merge request.
  - A campaign's integration branch is ready to surface on a forge.
  - Auditing forge-side presence at merge-consent or campaign CLOSE.
  - Prompt contains: /forge, pull request, PR body, merge request,
    forge discipline, PR review, stacked PR.
---

# Forge Discipline

**Applicability is conditional.** Some projects have no forge — a bare
remote, a patch workflow, or no remote at all — and nothing here applies
to them; absence of a forge is never a violation. **When the project has
a forge, this discipline applies in full.** The test is mechanical: does
the origin remote resolve to a forge the project accepts contributions
through?

## Philosophy: the forge is the public half of the record

The flight recorder (`.ledger/`) is the *internal* durable record; the
forge is the *external* one — the only record most future readers will
ever see. The two have different audiences and MUST NOT leak into each
other: the recorder may reference forge artifacts (they are public,
permanent URLs); forge prose MUST NEVER reference process-internal
state. A PR body that cites `.scratch/`, `.ledger/`, a session link, or
a working note is broken for every reader outside the process that
wrote it — and those are all of its readers.

## 0. Tooling: MCP for forge operations, git for merges

Forge **operations** — opening/updating PRs, posting comments and
reviews, reading state — prefer the forge's **MCP server** where the
session has one connected: structured, typed calls over stringly CLI
output. The CLI (`gh`, `glab`, …) is the fallback, and plain git+HTTPS
the primitive beneath both (degrade-to-the-primitive applies: never
depend on the MCP being present). The one hard exception runs the other
way: **merges are always the git CLI** (§4, MERGE_IN_GIT) — no MCP or
API merge endpoint, ever.

## 1. Branch ↔ PR mapping

- One integration branch, one PR. A campaign's `campaign/<TOPIC>` branch
  surfaces as a single PR; independent workstreams get independent
  branches and PRs, never one omnibus.
- **Stacked PRs** are permitted for dependent work: base each PR on its
  prerequisite's branch. Know the forge's mechanics: when a base branch
  merges and is deleted, the dependent PR retargets (or auto-closes as
  "closed", not "merged") — when the forge misclassifies, annotate the
  PR with the merge commit so the record reads correctly.
- Merged branches are deleted; the PR is the durable pointer.

## 2. PR prose — self-contained, or broken

- The body MUST be comprehensible to a reader with the repository and
  the PR alone: summary, what changed and why, decisions taken (with
  their grounds), what is deliberately out of scope, and honest
  verification status (what was run, what wasn't). Write for the human
  who will actually review it — a reader holding NONE of the campaign's
  context, not a colleague inside the process.
- **Zero process-internal references**: no `.scratch/`, no `.ledger/`,
  no sketch or session links, no "as discussed" — and no campaign-
  internal identifiers (node or finding tokens): to every reader outside
  the process they are dangling labels. Where context is load-bearing,
  use **permalinks pinned to a commit SHA** — branch-relative links rot
  when branches are deleted.
- The check is mechanical, not a memory: draft forge prose (PR bodies,
  issue bodies, review summaries) in a scratch file and run
  `gates/check_internal_ids.sh --files <draft>` over it before posting,
  the same standing gate merge review runs over shipped files.
- Verification claims in PR prose follow the same honesty rules as
  commit messages: state what evaluators ran and their actual results;
  never imply coverage that does not exist.

## 3. Review on the forge

Decorrelated review findings and their triage belong ON the PR, as
comments — the forge is where the review record survives:

- When adversarial or council review produces findings, post the
  findings (or a faithful summary) and the disposition of each —
  confirmed-and-fixed (with the commit), refuted (with grounds),
  deferred (with its follow-up home) — as PR comments.
- The triage comment is part of the merge record: a PR that merged
  after review with no visible trace of that review under-documents
  the merge.

## 4. Merge consent

- A PR merges only on the head's say-so, carried through the
  lead-maintainer seat's affirmative merge-consent where the council is
  seated ([campaign §RECONCILE](../campaign/SKILL.md)). Green checks
  and approving reviews are necessary, never sufficient.
- **Merge in git; the forge observes.** Merges are performed with the
  git CLI — locally, with the strategy the history actually calls for:
  fast-forward when clean, an octopus when many nodes land together, a
  merge commit where the narrative warrants one — then pushed; the
  forge detects the merge and closes the PR itself. The forge's merge
  API/button is NEVER the default: it constrains strategy to its own
  shapes (squash/rebase/single-merge), manufactures commits outside the
  commit gate's hygiene, and adds nothing the CLI lacks. After a CLI
  merge, verify the PR state and annotate if the forge misclassified it
  (closed-not-merged).
- Agents never push to protected/default branches without the head's
  explicit instruction (rules.md §3 applies unchanged on forges).
- **Preflight the authorized landing.** The final head-authorized push of
  an integration branch onto a long-lived default branch is a foreseeable
  campaign step: ensure at campaign setup that the permission environment
  allows it. If a classifier blocks it anyway, surface the block to the
  head as an environment gap — the merge is never rerouted through the
  forge's merge API to satisfy a classifier (MERGE_IN_GIT holds).

## 5. The forge audit

A checklist, not a ceremony — owned by the **composer**, run at two
points: alongside each merge-consent, and over the campaign's whole
forge surface at council CLOSE. The forge is the campaign's outward
communication, and communication is conducting: the composer authors
the forge surface, so the composer answers for it. The
lead-maintainer's gate is the CODE and its maintenance burden — his
attention stays on the diff, and routing this audit to him dilutes
the one review only he can give. The composer MAY delegate the
reading to a dedicated read-only reviewer when the surface is large;
the verdict and the fixes remain the composer's.

- [ ] PR prose still accurate against the *final* state of the branch
      (late commits silently invalidate early summaries).
- [ ] Self-containment holds: zero process-internal references
      anywhere in bodies or comments; permalinks pinned to SHAs.
- [ ] The review record is present: findings + triage visible on the
      PR for every review that gated the merge.
- [ ] Forge state matches reality: merged PRs show merged (or carry
      the correcting annotation); stale branches deleted; stacked PRs
      correctly retargeted.
- [ ] The PR set partitions the work meaningfully — a reader can
      navigate the campaign from the forge alone.
- [ ] The tracking-issue record is whole (§6): the meta issue exists,
      every out-of-scope finding has its own linked issue, and every
      issue body reads self-contained.

## 6. Campaign tracking issues

Out-of-scope findings are work the campaign discovered but will not do —
and undocumented, they evaporate with the campaign's scratch. The forge
is their durable home:

- **One meta tracking issue per campaign**, opened at campaign kickoff
  alongside the tracking PR. It is the campaign's out-of-scope index —
  a reader finds every deferred thread from this one issue.
- **One issue per out-of-scope finding**, opened when the finding is
  classified out of scope (at a reconcile boundary or at CLOSE), written
  self-contained per §2 — the finding's substance in repository terms,
  never its campaign-internal ID.
- **Link them**: sub-issues of the meta issue where the forge supports
  them (GitHub), plain cross-links otherwise. An unlinked issue is
  filed, not indexed.
- At CLOSE, every `ACCEPTED_RISK` disposition names its issue — the
  audit (§5) checks the record is whole. Acceptance without an issue is
  a silent drop wearing a disposition.

## Prime Directives

1. **CONDITIONAL_APPLICABILITY:** No forge, no obligation. A forge,
   full obligation.
2. **SELF_CONTAINED_PROSE:** Nothing process-internal ever reaches the
   forge. Permalinks over lore; SHAs over branch links.
3. **REVIEW_ON_RECORD:** Reviews that gated a merge are visible on the
   PR that merged.
4. **CONSENT_TO_MERGE:** Merge is a sovereignty act — the head's (via
   the lead-maintainer seat where seated), never an agent's default.
5. **MERGE_IN_GIT:** Merges happen in the git CLI, then push; the forge
   observes and records — it does not perform. The merge API is not an
   instrument.
6. **TRACKED_OUT_OF_SCOPE:** Every out-of-scope finding gets its own
   self-contained issue, linked from the campaign's meta tracking
   issue. Deferral is a routing decision with a durable address, never
   a silent drop.
