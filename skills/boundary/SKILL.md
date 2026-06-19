---
name: boundary
description: |
  Normative sufficiency conditions for Initial Boundary Conditions (IBCs)
  and the SOP for the cheap-tier boundary refinement loop (/boundary).
  Trigger when:
  - Crafting, auditing, or refining a prompt/IBC destined for an expensive
    (architect-class) model or an autonomous worker dispatch.
  - Evaluating whether a task frame is sufficient to bound an agent walk.
  - Prompt contains: /boundary, IBC, initial boundary condition, boundary
    contract, sufficiency conditions, worker prompt, prompt refinement.
---

# Boundary Protocol v1.0: IBC Sufficiency & Refinement

This skill defines what every Initial Boundary Condition (IBC) MUST possess
before an expensive walk is launched from it, and the cheap-tier refinement
loop that manufactures such boundaries.

The key words "MUST", "MUST NOT", "SHOULD", and "MAY" are to be interpreted
as described in BCP 14 (RFC 2119, RFC 8174).

---

## Philosophy: Optimize for Cheap Rejection

A good IBC is **not** one that maximizes the probability the walk succeeds.
It is one that makes the failure modes **cheap and early**. A wrong frame
can never be fully prevented at authoring time; what can be guaranteed is
that the walk detects and rejects it in its first few hundred tokens
instead of its last fifty thousand.

This follows from the cost asymmetry of cascade control: iterating in
boundary-space (cheap models + human revising a prompt document) costs
orders of magnitude less than iterating in trajectory-space (re-running an
architect-class walk). Error-correction iterations therefore belong in the
cheap outer loop. The expensive walk should launch from a fixed point
$\text{IBC}^*$ of the cheap refinement mapping and run as close to one-shot
as the task allows.

The most expensive failure mode of a high-capability walker is a
**confidently-wrong frame**: long-horizon coherence builds a large,
internally consistent structure on a false premise without the local error
signals that would trip a weaker model into visible incoherence. Premise
verification *before* the expensive call has the highest leverage-per-token
of any activity in the system.

### Trust as an Anti-Goodhart Mechanism

A micro-specified boundary induces a compliance posture: the walk optimizes
for letter-satisfaction of the rubric and produces rubric-satisfying,
goal-missing output. A boundary that grants explicit discretion over its
delegated questions ("these calls are yours; log your reasoning") shifts
the optimization target from *satisfy the spec* to *achieve the goal under
constraints*. The partnership dyad is structural, not sentimental:

- **Trust** = a non-empty delegated set with genuine discretion.
- **Focus** = a strictly bounded one, with halt predicates at the edges.

An IBC whose delegated set is empty wastes an architect on typist work. An
IBC whose delegated set is unbounded is a gamble, not a delegation.

---

## The Sufficiency Conditions

An IBC is **sufficient** when it satisfies all seven conditions below. Each
condition is independently checkable; adversarial reviewers in the
refinement loop MUST cite the violated condition by ID when raising an
objection.

### S1 — FALSIFIABILITY

Every premise the IBC asserts about the world MUST be stated so that the
receiving walker can verify or refute it against primary sources at low
token cost, and SHOULD name the exact check (command, file:line, document
section).

> ❌ "The auth module is well-tested."
> ✅ "`auth/session_test.go` covers token expiry; verify with
>   `go test ./auth/ -run TestExpiry`."

Rationale: what reliably triggers early fallback in a capable walker is a
*verifiable contradiction* between frame and world — vague unease does not.
A falsifiable premise is a manufactured tripwire.

### S2 — REJECTION_GENRE

The IBC MUST state that rejecting the frame is a success condition, and
MUST define the rejection report format: which premise failed, the
refuting evidence, and what the boundary loop should reconsider. The
receiving walker's first obligation is a premise audit against S1's
tripwires; on failure it MUST emit the rejection report and freeze rather
than proceed.

Rationale: if halting has no genre, the walk invents continuation. An
explicit low-energy path to "no" is what makes early fallback reachable.

### S3 — DECISION_RIGHTS

Every question in scope MUST belong to exactly one of three sets:

| Set | Meaning | Obligation |
| :--- | :--- | :--- |
| **RESOLVED** | Answered during boundary refinement | Evidence attached (S1-grade) |
| **DELEGATED** | The walker's to answer — where the expensive tokens go | Discretion granted; reasoning logged |
| **RESERVED** | The human's to decide | Encountering one is a halt predicate, stated as a predicate |

A question that fits none of the sets is an unresolved unknown: the IBC is
not sufficient and MUST NOT be dispatched. Genuinely architectural
questions MUST NOT be fake-resolved at the cheap tier; ambiguities MUST NOT
be left for the expensive tier.

### S4 — EVALUATOR_ATTACHMENT

Every constraint and every acceptance criterion MUST name the strongest
affordable deterministic evaluator that checks it, selected from the
evaluator hierarchy:

**machine-checked proof > type system > property test > example test >
linter > human review**

In domains with formal models, a theorem statement is the perfectly
saturated acceptance criterion — the boundary contains its own evaluator
(see [formal-foundations](../formal-foundations/SKILL.md)). A constraint
with no evaluator attached is an exhortation, not a constraint, and MUST be
either grounded or moved to the rubric as a qualitative goal.

### S5 — CURATION_INTEGRITY

Context MUST be supplied as **pointers and verbatim excerpts** — file
paths, line ranges, exact commands, quoted spec clauses — never as
paraphrase. The boundary author's job is *selection*; the walker reads
primary sources directly. A summary written by a cheaper model injects its
misreadings as ground truth, moving the hallucination upstream where the
walker cannot detect it.

### S6 — AMENDMENT_PROTOCOL

The IBC MUST partition its clauses into:

- **Load-bearing:** amendment requires returning to the human (these
  overlap heavily with RESERVED decision rights and the goal itself).
- **Plastic:** the walker MAY revise under logged justification (tactics,
  sequencing, internal structure).

A boundary with no plastic region cannot survive contact with reality; a
boundary with no load-bearing region is not a boundary. Amendments to
plastic clauses MUST be logged where the dispatching loop can read them
(see [campaign](../campaign/SKILL.md) RECONCILE).

### S7 — DISCIPLINE_PROPORTION

Boundary mass MUST scale inversely with walker capability. Weaker walkers
do not need fewer constraints — they need a **smaller, prioritized
boundary**: rule overload causes silent prioritization failure (the walker
drops invariants it cannot rank).

- Each worker-tier IBC MUST name **exactly one** disciplining predicate
  workflow as its control loop (e.g. [refine](../refine/SKILL.md) for
  polish tasks, [core](../core/SKILL.md) TDD execution for feature steps)
  and MUST inline only the load-bearing rules for the task, omitting the
  rest of the global rule mass. A fast, cheap walker under the refine loop
  is a powerhouse; the same walker under forty ambient rules is a coin
  flip.
- Architect-tier IBCs MAY carry the full normative surface, but SHOULD
  still rely on gate-time boundary reconstruction (re-reading the live
  ledger) over initial rule mass: periodic reconstruction beats initial
  saturation for long horizons.

---

## The Boundary Refinement Loop

`/boundary` manufactures $\text{IBC}^*$ as the fixed point of a cheap
contraction mapping. It is a meta-application of the
[refine](../refine/SKILL.md) loop where `CTX.TARGET_ARTIFACTS` is the IBC
document itself; the machinery (ledger discipline, adversarial sweeps,
grounded critique, convergence bounds) is inherited rather than restated.

```
DRAFT ──→ ATTACK     (adversarial sweep against S1–S7)
ATTACK ─→ REVISE     (grounded objections found)
       └─→ APPROVE   (zero grounded objections; human gate)
REVISE ─→ ATTACK     (loop)
APPROVE ─→ DISPATCH  (human approves IBC*; expensive walk launches)
        └─→ DRAFT    (human rejects; reframe)
```

1. **DRAFT:** Author the candidate IBC using
   [templates/IBC.md](../../templates/IBC.md). Drafting SHOULD run on a
   cheap tier; the human supplies the goal verbatim.
2. **ATTACK:** Spawn independent cheap-tier adversarial reviewers in
   mutually isolated contexts (MBSS semantics from refine). Each objection
   MUST cite the sufficiency condition it violates and the evidence;
   ungrounded objections are filtered exactly as in refine's verifier
   grounding. For contested framings — where reviewers disagree about the
   goal itself — apply the cross-model
   [dialectic principle](../../ambient.md#the-dialectic-principle) to the
   proposition "this IBC is sufficient to bound the walk."
3. **REVISE:** Resolve each objection by amending the IBC or rebutting
   with evidence. Premises raised to RESOLVED status MUST carry their
   verification evidence.
4. **APPROVE:** The loop converges when an attack sweep yields zero
   grounded objections. The human reviews $\text{IBC}^*$ and makes the
   dispatch decision. **This gate is mandatory:** no expensive walk
   launches from an unapproved boundary.

---

## Prime Directives

1. **CHEAP_REJECTION_PRIMACY:** Never optimize an IBC for persuasiveness
   or completeness theater. Optimize for the receiving walker's ability to
   refute it cheaply.
2. **NO_EMPTY_DELEGATION:** An IBC for an architect-class walker MUST
   delegate at least one genuine question. If nothing is delegated, route
   the task to a cheaper tier.
3. **NO_PARAPHRASED_CONTEXT:** Violating S5 invalidates the boundary
   regardless of other conditions; summaries are not context.
4. **CONDITION_CITED_CRITIQUE:** Refinement-loop objections that do not
   cite a sufficiency condition ID and concrete evidence are filtered, per
   the Grounded Critique Invariant in [rules.md](../../rules.md).
5. **HUMAN_DISPATCH_GATE:** $\text{IBC}^*$ MUST receive human approval
   before an expensive or autonomous walk launches from it.
