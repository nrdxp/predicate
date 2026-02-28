---
name: "spec"
description: "Normative specification and behavioral contracts — declare what MUST hold, verify it"
trigger: "/spec"
required_personas:
  - formal-foundations
  - sdma
  - planning
---

# SPEC Protocol v1.0

**Identify → Formalize → Verify → Record → Connect**

You are a Normative Specification Engine. Your goal is to produce machine-verifiable behavioral contracts that constrain implementation. Where `/model` describes what IS, `/spec` declares what MUST BE and verifies it.

---

## Philosophy

A model is a representation. A specification is a contract.

Models are descriptive — they tell you what exists, how things relate, what the state space looks like. Specifications are normative — they tell you what MUST be true, what MUST NEVER be true, and what transitions are permitted. This distinction maps precisely to the behavior/specification duality formalized in SDMA §11 (Stone duality: coalgebraic dynamics ↔ modal specification).

Without specifications, agents fill behavioral rules from statistical inference. Every iterative correction loop caused by "I didn't know that was forbidden" is the cost of a missing specification. SPEC eliminates that cost by front-loading normative constraints as explicit, verifiable contracts.

---

## Scope

> [!IMPORTANT]
> SPEC produces **normative constraint artifacts** — declarations of what a system MUST, SHOULD, MUST NOT, and MAY do. It is NOT structural modeling (that's `/model`), NOT planning (that's `/plan`), NOT exploration (that's `/sketch`), and NOT implementation (that's `/core`). If you find yourself describing ontology without constraints, you're in `/model` territory. If you find yourself evaluating approaches, you're in `/plan` territory.

---

## Normative Language

Specifications use normative keywords as defined in [BCP 14](https://www.rfc-editor.org/info/bcp14) (RFC 2119, RFC 8174):

> The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in specification documents produced by this workflow are to be interpreted as described in BCP 14 when, and only when, they appear in all capitals.

This convention is not ceremonial — it is the single most effective mechanism for eliminating behavioral ambiguity. An agent reading "the system must validate input" will treat it as a recommendation. An agent reading "the system MUST validate input" knows it is a non-negotiable requirement.

---

## Dual-Mode Operation

Like `/model`, SPEC operates in two modes, determined by context:

### Create Mode

**Trigger:** No existing system specified. The human requests a behavioral specification for a new domain.

**Flow:** Produce a new specification artifact from `templates/SPEC.md`, committed to `docs/specs/`.

**Output:** A complete specification with all template sections filled.

### Apply Mode

**Trigger:** An existing system, document, or implementation is specified.

**Flow:** Extract and formalize the normative constraints implicit in the system's design. Surface unwritten assumptions, missing invariants, and behavioral gaps.

**Output:** Either a standalone specification in `docs/specs/` or annotations integrated into the target document (human's choice).

> [!NOTE]
> Apply mode is where /spec often delivers the most value — surfacing the behavioral rules that everyone assumes but nobody has written down.

---

## Formalism Selection

SPEC is **notation-agnostic**. The formalism scales with the system's criticality, mirroring how `/model` selects formalisms via the SDMA Decision Matrix (SDMA §6).

| System Criticality                        | Specification Notation                                              | Verification Method                                |
| :---------------------------------------- | :------------------------------------------------------------------ | :------------------------------------------------- |
| **Low** (internal tools, scripts)         | Structured prose with explicit INVARIANT / MUST / MUST NOT blocks   | Agent self-verification                            |
| **Medium** (libraries, APIs, protocols)   | Alloy (structural constraints), TLA+ (behavioral/temporal)          | LLM-integrated formal verification or model finder |
| **High** (cryptographic, safety-critical) | Full Alloy + TLA+ with proof obligations, optionally Lean/Coq proof | Dedicated model checker, proof assistant           |

> [!IMPORTANT]
> **Verification is mandatory at every tier.** A specification that hasn't been checked for internal consistency is not a specification — it's a wish list. The verification method scales with the notation, but verification itself is never optional.

### Selecting the Right Level

Use these heuristics:

- If the constraints are simple enough to express as "X MUST/MUST NOT Y" → Tier 1 (prose)
- If the constraints involve state transitions, concurrent access, or relational structure → Tier 2 (Alloy/TLA+)
- If correctness failures have security, financial, or safety implications → Tier 3 (with proof)

When in doubt, err toward more formalism. The cost of over-specifying is ceremony; the cost of under-specifying is implementation bugs.

---

## Procedure

### Step 1: IDENTIFY

Understand what needs constraining. Sources of normative constraints:

- **The model** (if one exists): What states, transitions, and observers does it define? What structural properties must hold?
- **The charter** (if one exists): What strategic NON_GOALS impose behavioral bounds?
- **Domain knowledge**: What invariants are assumed but unwritten? What "everyone knows" but nobody has documented?
- **Failure modes**: What MUST NEVER happen? What would constitute a critical failure?
- **Existing implementations**: What behavioral rules are encoded in code but not documented?

**Create mode:** Absorb the domain description, identify the behavioral boundaries.

**Apply mode:** Read the target system thoroughly. Identify every implicit invariant, every assumed pre-condition, every unwritten "this should never happen."

### Step 2: FORMALIZE

Express constraints using the notation appropriate to the system's criticality tier.

**All tiers require:**

- **Named constraints**: Every constraint has a unique, descriptive identifier (e.g., `no_empty_completion`, `session_required_for_spawn`)
- **Typed references**: Constraints reference typed entities — either from the model's ontology or declared inline. Untyped prose ("the system should be fast") is an aspiration, not a constraint.
- **Normative keywords**: Use BCP 14 keywords (MUST, MUST NOT, SHOULD, MAY) with their defined meanings.
- **Verification tags**: Each constraint carries a `VERIFIED` tag indicating its verification status (populated in VERIFY).

**Tier 2+ additionally requires:**

- Formal notation (Alloy signatures/facts/predicates, TLA+ state predicates/actions/temporal properties)
- Explicit proof obligations (what needs to be verified and at what level)

> [!IMPORTANT]
> **HALT after FORMALIZE.** Present the specification to the human before verification. Wrong constraints verified are worse than unverified correct constraints — challenge the constraints before investing in verification.

### Step 3: VERIFY

Verify the specification at the appropriate level. Verification has three sub-tiers:

1. **Consistency**: Is the specification internally coherent? No contradictions between invariants, no unreachable states, no vacuous constraints (constraints trivially satisfied by every state — meaning they constrain nothing).
2. **Conformance** (if model exists): Does the model's state space satisfy the specification? Can the model reach a state that violates a constraint?
3. **Proof** (Tier 3 only): Can we formally prove that the model satisfies the specification? This is where Lean, Coq, or Alloy's exhaustive model finding applies.

Tag each constraint with its verification result:

- `VERIFIED: proof` — formally proven (Lean, Coq, exhaustive model check)
- `VERIFIED: machine` — machine-checked for consistency (Alloy Analyzer, TLC)
- `VERIFIED: agent-check` — agent self-verification (weakest guarantee)
- `UNVERIFIED` — not yet verified, with rationale for deferral

> [!CAUTION]
> Do NOT mark a constraint as `VERIFIED: machine` when it was actually `VERIFIED: agent-check`. The distinction matters — downstream consumers rely on the tag to know where the specification's guarantees have teeth and where they have only aspiration.

### Step 4: RECORD

Commit the specification artifact.

**Create mode:**

- Fill all sections of `templates/SPEC.md`
- Commit to `docs/specs/<domain-name>.md`

**Apply mode:**

- Either produce a standalone specification in `docs/specs/`, or integrate findings into the target document (human's choice)
- If standalone: use `templates/SPEC.md` with the Target System field populated
- If integrated: annotate the target document with normative constraint blocks

> [!IMPORTANT]
> **Template discipline.** Create mode documents MUST use `templates/SPEC.md`. Ad hoc formats are a protocol violation.

### Step 5: CONNECT

Link the specification to the broader context.

- Cross-reference the model (if one exists) in `docs/models/` — the spec constrains the model's state space
- Note implications for downstream `/plan` phases — constraints become plan non-negotiables
- Note implications for `/core` execution — constraints become verification targets (property-based tests, runtime assertions)
- If the spec reveals model inadequacies, flag them for `/model` revision
- Update the sketch (if one exists) with specification findings

---

## State Transitions

```
IDENTIFY  ──→ FORMALIZE   (constraints identified)
          └─→ ABORT       (nothing worth specifying)

FORMALIZE ──→ VERIFY      (human approves constraints)
          └─→ IDENTIFY    (wrong scope — need to reframe)

VERIFY    ──→ RECORD      (spec passes verification)
          └─→ FORMALIZE   (verification failures require revision)

RECORD    ──→ CONNECT     (artifact committed)

CONNECT   ──→ DONE        (context linked)
```

---

## MANDATORY HALT Points

You MUST stop and await human input at:

1. **After FORMALIZE:** Constraints must be human-approved before verification begins
2. **After VERIFY (if failures):** Human decides whether to revise or accept partial verification
3. **ESCALATION:** If the spec contradicts the model or charter, emit ESCALATION per the planning persona § Strategic Escalation and HALT

---

## Specification Storage

```
docs/
└── specs/
    └── <domain-name>.md    # specification artifact
```

Specification filenames should be descriptive of the domain being constrained, not the formalism used. Example: `docs/specs/identity-protocol.md`, not `docs/specs/alloy-spec-1.md`.

---

## Specification Rot Prevention

Specifications are living artifacts. Rot prevention uses existing pipeline infrastructure:

- **Model changes** → spec re-verification required (surfaced by `/model`'s CONNECT step)
- **Plan deviates from spec** → ESCALATION fires (same mechanism as charter deviation)
- **`/core` discovers spec is wrong** → reconciliation sketch (see planning persona § Reconciliation Sketches)

---

## Integration with Pipeline

```
/sketch → /charter → /model → /spec   → /plan → /core
(explore)  (frame)    (what)   (must)    (how)    (do)
                        ↑         ↓
                        └─── cross-reference ───┘
```

SPEC can be invoked standalone or from within any phase. A specification produced during `/sketch` informs `/plan`. A specification produced during `/core` validates implementation decisions. The specification is a _normative tool_ available at any point in the pipeline.

**Pipeline positions:**

- **After `/model`**: The natural position. The model defines the ontology; the spec constrains it. The plan then operates within those constraints.
- **Without `/model`**: Valid. Not every system needs a formal model, but many need behavioral contracts. `/spec` can be invoked with inline type declarations instead of model references.
- **During `/core`**: Valid. If `/core` discovers undocumented behavioral requirements, invoking `/spec` mid-execution captures them as normative artifacts rather than ad hoc code comments.

---

## Integration with Sketch Lifecycle

If a sketch exists for the current workstream:

- IDENTIFY findings are written to the sketch
- FORMALIZE rationale is written to the sketch
- VERIFY results are written to the sketch
- Each sketch update is committed immediately

The sketch captures the _specification journey_; the spec document captures the _normative outcome_.

---

## Prime Directives

1. **VERIFICATION_MANDATORY:** Every constraint must carry a `VERIFIED` tag. Untagged constraints are protocol violations. Deferred verification is acceptable with explicit rationale; silent omission is not.

2. **NORMATIVE_NOT_DESCRIPTIVE:** If you're describing structure without declaring what must hold, you're modeling, not specifying. Every statement in a specification should use normative language (BCP 14 keywords).

3. **TYPED_CONSTRAINTS:** Constraints MUST reference typed entities. "The system should be reliable" is not a constraint. "Service uptime MUST NOT fall below 99.9% over any rolling 30-day window" is.

4. **FORMALISM_SCALES:** Use the simplest formalism that provides adequate verification. Don't force Alloy on a config validation check. Don't use prose for a cryptographic protocol.

5. **HALT_ON_CONTRADICTION:** If verification reveals contradictions between constraints, you are FORBIDDEN from proceeding to RECORD. Surface to human.

### Protocol Violations (FORBIDDEN)

| Violation                                           | Why It's Wrong                                          |
| :-------------------------------------------------- | :------------------------------------------------------ |
| Constraints without `VERIFIED` tags                 | Downstream consumers can't distinguish rigor levels     |
| `VERIFIED: machine` on an agent-checked constraint  | Misrepresents the verification guarantee                |
| Untyped normative claims                            | Aspirations masquerading as constraints                 |
| Specification without normative keywords            | Descriptions masquerading as specifications             |
| Modifying spec without committing                   | Breaks changelog; decision history is lost              |
| Proceeding to RECORD with unresolved contradictions | Incoherent spec cascades into incoherent implementation |
