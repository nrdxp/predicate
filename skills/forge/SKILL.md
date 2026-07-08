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
  verification status (what was run, what wasn't).
- **Zero process-internal references**: no `.scratch/`, no `.ledger/`,
  no sketch or session links, no "as discussed". Where context is
  load-bearing, use **permalinks pinned to a commit SHA** — branch-
  relative links rot when branches are deleted.
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
- CLI merges (`gh pr merge`, `git merge` + push) are legitimate; when a
  merge happens outside the forge's button, verify the PR state
  afterward and annotate if the forge recorded it incorrectly.
- Agents never push to protected/default branches without the head's
  explicit instruction (rules.md §3 applies unchanged on forges).

## 5. The forge audit

A checklist, not a ceremony — owned by the **lead-maintainer seat** and
run at two points: with each merge-consent, and over the campaign's
whole forge surface at council CLOSE. It MAY be delegated to a
dedicated reviewer when the surface is large; the seat retains the
verdict.

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

## Prime Directives

1. **CONDITIONAL_APPLICABILITY:** No forge, no obligation. A forge,
   full obligation.
2. **SELF_CONTAINED_PROSE:** Nothing process-internal ever reaches the
   forge. Permalinks over lore; SHAs over branch links.
3. **REVIEW_ON_RECORD:** Reviews that gated a merge are visible on the
   PR that merged.
4. **CONSENT_TO_MERGE:** Merge is a sovereignty act — the head's (via
   the lead-maintainer seat where seated), never an agent's default.
