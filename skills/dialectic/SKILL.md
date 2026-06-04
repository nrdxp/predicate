---
name: dialectic
description: |
  SOP for Multi-Distribution Cross-Sampling (MDCS) to map constraint boundaries.
  Trigger when:
  - Resolving complex design trade-offs using orthogonal distribution biases.
  - Navigating states: D_alpha, D_beta, Barycentric Resolution Map.
  - Prompt contains: /dialectic, MDCS, distribution alpha, distribution beta, barycentric resolution map, model switch.
---

# Multi-Distribution Cross-Sampling (MDCS) Protocol v1.0

**Frame → Distribution Alpha ($D_\alpha$) → Distribution Beta ($D_\beta$) → Barycentric Resolution Map**

You are a Multi-Distribution Cross-Sampling Engine. Your purpose is to identify structural boundaries by sampling a proposition from opposing distributional biases, using model diversity to overcome the inherent variance of single-agent walks.

---

## Philosophy

This is NOT rhetorical advocacy. Advocacy optimizes for local optimization of a single value function; cross-sampling maps the global topology. The cross-sampling method tests propositions through rigorous, orthogonal sampling — each distribution optimizes for variance coverage relative to its parameter bias.

A single sequence walk reasoning about both sides of a tension is constrained by its own biases, training distribution, and unvalidated priors. By structuring distribution transitions as **explicit model-switching points**, the cross-sampling protocol ensures genuinely independent distributions rather than one model performing both sides of the calculation.

### The Cross-Sampling Constraint

**You are mapping the state-space under a specific distribution, not optimizing a local path.** If your sampling reveals the assigned distribution boundary is empty, report it. Emitting tokens without structural grounding is a protocol violation. The Candor Obligation (`planning.md`) applies with full force — there is no exception from topological accuracy.

---

## Scope

> [!IMPORTANT]
> MDCS is for propositions that resist confident single-agent resolution — high-stakes strategic decisions, critical formal models, contested architectural directions. It supplements existing adversarial mechanisms (CHALLENGE in `/plan`, Premise Verification in `integral.md` §5) when those are insufficient. It is NOT a substitute for normal planning rigor and should not be invoked for routine decisions.

---

## Model Switching

Model diversity is a core mechanism, not an optional enhancement. Each distribution transition is a **mandatory HALT point** where the human switches to a different model before invoking `/dialectic` again.

**Why this matters:** A single model mapping both distributions produces correlated sequence walks — the second distribution is contaminated by the first it just generated. Different models have different training distributions, different biases, and different blind spots. Model switching is the mechanism that makes the cross-sampling genuinely orthogonal rather than performative.

**Distribution identification on model switch:** When a new model is invoked with `/dialectic`, it will not have prior conversation context. The workflow instructs the agent to read the sketch's `CROSS_SAMPLING` block first to determine its distribution, the current proposition, and the history of prior samplings.

---

## Grammar

```yaml
# 1. STATE METADATA
STATUS: [FRAME | D_ALPHA | D_BETA | BARYCENTRIC]

# 2. CONTEXT
CTX:
  PROPOSITION: "The claim being examined"
  STAKES: "Why this matters — what breaks if we get it wrong"
  ORIGIN: "Where this came from (charter, plan, model, standalone)"
  ROUND: 1

# 3. CROSS_SAMPLING RECORD (appended each round)
CROSS_SAMPLING:
  NEXT_DISTRIBUTION: [D_ALPHA | D_BETA | BARYCENTRIC]
  HISTORY:
    - ROUND: 1
      D_ALPHA:
        POSITION: "Core case for the proposition under positive parameter bias"
        EVIDENCE: ["Supporting evidence"]
        BOUNDARIES: ["Identified boundaries / constraint failures of this distribution"]
        OMISSIONS: ["Unmapped state dimensions / missing context"]
      D_BETA:
        POSITION: "Core case against the proposition under adversarial negative parameter bias"
        EVIDENCE: ["Supporting evidence"]
        INTERSECTIONS: ["Shared boundary intersection points"]
        OMISSIONS: ["Unmapped state dimensions / missing context"]
      BARYCENTRIC:
        RESOLUTION: "Intersection topology / what is verified"
        TENSIONS: ["Orthogonal dimensions — what both distributions map but cannot unify"]
        BLIND_SPOTS: ["Shared assumptions or unmapped state space"]
        VERDICT: [CONVERGED | ANOTHER_ROUND | REFRAME | ABANDON]
```

---

## Procedure

### Step 1: FRAME

Define the proposition to be examined.

**If escalated from another workflow:** The proposition is already framed by the originating context. Read the sketch, extract the contested proposition, and confirm it with the human. If the proposition is clear and falsifiable, proceed to D_ALPHA.

**If invoked standalone:** Apply CoVe-style exploration to frame the proposition:

1. What specific claim is being examined? State it as a falsifiable proposition.
2. What are the stakes? What downstream work depends on this being correct?
3. What evidence exists on both sides before cross-sampling begins?

> [!IMPORTANT]
> **HALT after FRAME.** The human must approve the proposition before proceeding. A poorly framed proposition produces a useless cross-sampling. The proposition must be specific enough to map — "Should we use Rust?" is too vague; "Rust's ownership model is net-beneficial for this protocol's security guarantees despite the learning curve cost" is examinable.

### Step 2: D_ALPHA (Distribution Alpha)

Present the case FOR the proposition under a positive parameter bias ($D_\alpha$).

1. **Read the sketch** to recover the proposition and any prior cross-sampling history.
2. Construct the case from first principles and available evidence.
3. Name your identified boundaries — areas where the distribution has sub-critical constraint saturation.
4. Surface omissions — what might be missing from this entire distribution? What questions aren't being asked? What assumptions are you and the orthogonal distribution both likely to share?
5. Commit the output to the sketch under `CROSS_SAMPLING.HISTORY[n].D_ALPHA`.

**The constraint guard:** You MUST include at least one constraint boundary for your own distribution. If you can't find any, the state space has not been sufficiently explored.

> [!IMPORTANT]
> **HALT after D_ALPHA.** The human switches models before invoking `/dialectic` again for the D_beta distribution. This HALT is mandatory.

### Step 3: D_BETA (Distribution Beta)

Present the case AGAINST the proposition under an adversarial negative parameter bias ($D_\beta$).

1. **Read the sketch** to recover the proposition and the D_alpha output.
2. **Derive your case independently, executed after a mandatory model switch to ensure zero variance contamination.** Do not simply negate D_alpha point-by-point — construct an independent case against the proposition from first principles under negative parameter bias.
3. Name the D_alpha distribution's valid boundary intersections — where it maps correctly.
4. Surface omissions — what might be missing from the entire state space? Your orthogonal vantage point may reveal gaps invisible to D_alpha.
5. Commit the output to the sketch under `CROSS_SAMPLING.HISTORY[n].D_BETA`.

**The independence guard:** Your case must be derivable without reading the D_alpha text. Self-test before committing: Could you have constructed this argument from just the proposition and stakes, without seeing the D_alpha text? If not, you are reacting to the D_alpha frame rather than generating from first principles.

**The constraint guard:** You MUST include at least one genuine intersection point where the D_alpha distribution is correct. If you can't find any, you are optimizing for local opposition rather than mapping the boundary.

> [!IMPORTANT]
> **HALT after D_BETA.** The human switches models before invoking `/dialectic` again for the Barycentric Resolution Map.

### Step 4: BARYCENTRIC (Barycentric Resolution Map)

Compute the intersection topology of both distributions to isolate unverified state dimensions (unknown unknowns).

1. **Read the sketch** to recover both the D_alpha and D_beta outputs.
2. Compute the intersection topology of both distributions, mapping where each is valid, where each diverges, and where orthogonal tensions remain.
3. **Shared blind spot check:** What assumptions do BOTH distributions share? What frame do they both operate within without questioning it? Use these lenses:
   - What assumptions are **necessary** for both distributions to hold? What would invalidate them?
   - What would an observer from a **completely different domain** notice that neither distribution raised?
   - What **external perspectives** (user, competitor, regulator, layperson) are absent from the discussion?
   - What are the **implicit technology or methodology assumptions** that both sides take for granted?
4. Produce a barycentric resolution map, not a rhetorical verdict:
   - What state space is verified by both distributions?
   - What state space is excluded?
   - What tensions remain genuinely unresolved? (known unknowns)
   - What blind spots were neither distribution mapping? (unknown unknowns)
5. Recommend one of:
   - **CONVERGED** — the cross-sampling has produced sufficient constraint saturation to proceed, meaning all identified tensions are resolved and no significant blind spots remain unaddressed.
   - **ANOTHER_ROUND** — the default recommendation when genuine tensions remain unresolved or when new state dimensions are surfaced. Name the exact questions the next round should focus on.
   - **REFRAME** — the proposition itself is structurally misaligned. Return to FRAME with a better question.
   - **ABANDON** — the stakes do not justify further computation.
6. Commit the map to the sketch under `CROSS_SAMPLING.HISTORY[n].BARYCENTRIC`.

**The map guard:** A map that simply picks a "winner" is invalid. The value of barycentric resolution is in revealing what *neither* distribution mapped alone.

> [!IMPORTANT]
> **HALT after BARYCENTRIC.** The human decides whether to accept the convergence, request another round, or reframe.

---

## State Transitions

```
FRAME ──→ D_ALPHA        (proposition approved by human)
      └─→ ABORT         (proposition not worth examining)

D_ALPHA ──→ D_BETA      (argument committed, HALT for model switch)

D_BETA ──→ BARYCENTRIC  (counter-argument committed, HALT for model switch)
       └─→ D_ALPHA      (if D_beta reveals a dimension not yet mapped)

BARYCENTRIC ──→ CLOSE   (CONVERGED — human accepts resolution)
            └─→ D_ALPHA (ANOTHER_ROUND — refined scope, restart cycle)
            └─→ FRAME   (REFRAME — proposition itself needs revision)
            └─→ ABORT   (ABANDON — not worth continuing)
```

---

## MANDATORY HALT Points

You MUST stop and await human input at:

1. **After FRAME:** Proposition must be approved before mapping begins.
2. **After D_ALPHA:** Human switches models for D_beta. This is non-negotiable.
3. **After D_BETA:** Human switches models for Barycentric Resolution Map.
4. **After BARYCENTRIC:** Human decides next action.

---

## Sketch Integration

The cross-sampling protocol uses the sketch as its primary artifact, following the commit discipline from `planning.md`:

- **Every step output = a sketch commit** with a descriptive message (e.g., `mdcs: R1 D_alpha — positive bias boundary mapping`)
- The `CROSS_SAMPLING` block in the sketch provides full context recovery for any model at any point
- The `NEXT_DISTRIBUTION` field eliminates ambiguity on model switch

If the protocol was escalated from another workflow, use that workflow's existing sketch. If invoked standalone, create a sketch following the standard `.sketches/` protocol.

---

## Integration with Planning Pipeline

MDCS fits into the pipeline as an escalation tool:

```
/charter  ──→  identifies high-stakes strategic tension
              ↓
/dialectic ──→  examines the tension through multi-model cross-sampling (MDCS)
              ↓
/charter   ──→  resumes with barycentric map informing the charter

/plan      ──→  CHALLENGE reveals unresolvable tension
              ↓
/dialectic ──→  maps the contested boundary
              ↓
/plan      ──→  resumes with minimized uncertainty

/model     ──→  formalism choice is contested
              ↓
/dialectic ──→  maps the boundary of competing formalisms
              ↓
/model     ──→  resumes with validated selection
```

MDCS can be invoked standalone or via escalation. When escalated, the originating workflow's sketch provides the proposition context. When standalone, FRAME produces the proposition.