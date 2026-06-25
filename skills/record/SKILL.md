---
name: record
description: |
  Ambient record-keeping and promotion procedure for any predicate-enabled walk.
  Trigger when:
  - Classifying a step's output for recording (decision, finding, working detail).
  - Promoting a scratch artifact to the ledger or to repo/docs.
  - Auditing whether a draft is structurally ready for its destination.
  - Running a zero-context sensibility read before committing to promotion.
  - Prompt contains: /record, record-keeping, promote, ledger note, zettelkasten,
    scratch-to-ledger, zero-context read, over-strip, classification trigger.
---

# Record & Promotion

**Ambient** — applies to every predicate-enabled walk, not campaign-only. Depth
scales with stakes: a routine finding gets a one-line tracker update; a
strategic pivot gets a linked ledger note + a zero-context sensibility pass.

---

## Core model

Three substrates with distinct roles:

| substrate | role | character |
| :-- | :-- | :-- |
| `scratch` | exhaustive working detail; coherent context being built | default ephemeral; sometimes a draft staged for promotion |
| `ledger` (`.ledger/log/`) | zettelkasten — linked, curated trail of *how the space was explored*: decisions, pivots, adjustments | NOT exhaustive; navigable graph |
| `repo/docs/` | promoted durable artifacts (a design that graduated) | permanent |

**Promotion** is the combinator `promote(from, to)` over `{scratch, ledger, repo}`.
The destination is routed by purpose, not by artifact type.

---

## Recording (continuous)

At each significant step, classify the output and record it — this is a
**classification trigger**, not a rulebook. Ask: what kind of thing just happened?

| what happened | where it goes | minimum record |
| :-- | :-- | :-- |
| **decision / pivot / adjustment** | linked ledger note | what, why, which `[[decisions/KUs]]` it changes; link to superseded/resolved notes |
| **finding** (new R/I/U item) | update the live R/I/U tracker; ledger note if it pivots direction | tracker entry with grounding + last\_validated + signpost |
| **working detail / draft** | scratch | no ceremony; stage for promotion when ready |

**Linking discipline.** Ledger notes are a zettelkasten: each note links
(`supersedes`, `resolves`, `blocks`, `see-also`) to the nodes it affects. The
ledger is a navigable graph, not a flat append log. Every-touch-commit
([Sketch Commit Discipline](../../ambient.md#planning-invariants)) keeps the
graph linear and reconstructable.

**Formal side.** The presence check is: is there a ledger note for this pivot?
The substantive side is: is the trail reconstructable by a future agent from the
notes alone? — closed by review.

---

## Promotion

### Destination routing (the combinator's dispatch table)

`promote(from, to)` routes by the artifact's **purpose**:

- needed to reconstruct *how/why* but not general documentation →
  **ledger** (zettelkasten; future agents in this exploration)
- a durable artifact useful to someone who never saw the exploration →
  **repo/docs** (a user / zero-context agent)
- cross-cases: `scratch → ledger`, `scratch → repo`, `ledger → repo`

The "stranger" for the zero-context sensibility read is parameterized by the
destination's audience. The over-strip line moves with the destination:

- **ledger stranger** — a future agent reconstructing this campaign; still
  needs decisions + why
- **repo stranger** — a user who never saw the exploration; needs none of the
  session context

### Gate 1 — structural readiness (machine-checkable)

The artifact must conform to its destination's contract before promotion:

- a draft IBC must pass `worker_ibc.ncl` export
- a DAG node must export cleanly against `dag.ncl`
- a skill draft must carry valid YAML frontmatter (this file's own gate)
- a doc must have valid local links and header structure

Does not export / does not conform → **not ready**. Do not proceed to Gate 2.
This makes "structurally ready" machine-checkable rather than a judgment call.

### Gate 2 — sensibility (zero-context multi-round read)

A quality mechanism, not a box to tick. Read the draft as a stranger with
**only its stated purpose**; surface everything that is only meaningful in-session:

- references to "what we discussed" or "as above"
- implicit assumptions the reader cannot recover
- scratch-isms (abbreviations, shorthand, agent-internal labels)

Strip or make-explicit each; iterate until a context-free read is fully sensible.

**Over-strip guard** — strip only what is session-meaningful AND not needed for
the stated purpose. Before stripping anything, ask:

> *Does a stranger with the stated purpose need this to understand / use the
> artifact?*

Yes → keep and make explicit. "Merely discussed in session" → strip.
**Never strip load-bearing rationale.** A sensibility read that removes
rationale is a context-destroyer, not a quality pass.

Depth scales with stakes and destination:
- routine scratch note → ledger: self-administered flush-read
- architectural or doctrine artifact → repo: decorrelated agent review
  ([refine](../refine/SKILL.md) REVIEW semantics)

### Gate 3 — role authorization (privileged)

Promotion is role-gated:

| artifact class | who may promote |
| :-- | :-- |
| working detail / findings → ledger | any walker |
| full architecture / spec → repo/docs | architect-tier |
| doctrine edits (rules.md, ambient.md, formalism) | **Reserved halt** — human approval required before merge |

A worker cannot unilaterally promote to durable doctrine. On doctrine promotion,
emit the draft and halt for human review before touching the destination.

### On promote: link the durable artifact

After promotion:

1. Strip ephemera (Gate 2 already handled this).
2. Write a ledger note recording the promotion: what was promoted, where it
   landed, and why it graduated. This keeps the zettelkasten honest about the
   artifact's provenance.

---

## Adaptive extension

This skeleton fleshes against the concrete R/I/U at hand. Minimum floor:

- **Recording:** classify the step; write the minimum record for its class.
- **Promotion:** pass structural readiness (Gate 1) before touching Gate 2.

Extend selectively when not converged: add rounds to the sensibility read when
the artifact is high-stakes or the over-strip risk is real; add a decorrelated
reviewer when promoting doctrine; tighten the linking discipline when the ledger
is the primary reconstruction surface.

The skeleton supports shape AND flexibility — it does not prevent movement. Do
not inflate it into an exhaustive script.

---

## Two-purpose inheritance

Following P-GROUND's two-purpose principle:

- **Recording** — formal gate: did you classify and record the step? (presence-
  checkable); substantive gate: is the trail reconstructable? (closed by review).
- **Promotion** — formal gate: does the artifact pass structural readiness?
  (machine-checkable via contract conformance); substantive gate: is the
  zero-context read fully sensible? (closed by the multi-round read + role-gated
  reviewer, depth-to-stakes).

The contract is the "did-they-try" floor that feeds the review; the review is
where substance is judged. Do not fake a smarter contract.
