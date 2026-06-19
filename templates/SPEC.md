# SPEC: [Domain Name]

<!--
  SPEC documents are normative specification artifacts produced by the /spec workflow.
  They declare behavioral contracts that constrain implementation — what MUST be true,
  what MUST NEVER be true, and what transitions are permitted.

  The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
  "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this
  document are to be interpreted as described in BCP 14 (RFC 2119, RFC 8174) when,
  and only when, they appear in all capitals, as shown here.

  See: skills/spec/SKILL.md for the full protocol specification.
  See: skills/formal-foundations/SKILL.md for the mathematical foundations.
  See: skills/sdma/SKILL.md for the applied modeling toolkit.
-->

## Domain

<!-- What system or domain is being specified? What are its boundaries?
     Reference the formal model if one exists (docs/models/<domain>.md).
     If no model exists, declare types inline in the Constraints section. -->

**Problem Domain:**

**Target System:** <!-- Apply mode only. Remove this line in Create mode. -->

**Model Reference:** <!-- Link to docs/models/<domain>.md if available. Remove if none. -->

**Criticality Tier:** <!-- Low | Medium | High — determines formalism and verification level.
     See skills/spec/SKILL.md § Formalism Selection for tier definitions. -->

## Constraints

<!-- The normative core of this document. Every constraint MUST:
     1. Have a unique, descriptive identifier
     2. Reference typed entities (from the model or declared inline)
     3. Use BCP 14 normative keywords (MUST, MUST NOT, SHOULD, MAY)
     4. Carry a VERIFIED tag (populated after the VERIFY step)

     Organize constraints by category. Common categories below — add or
     remove as appropriate for the domain. -->

### Type Declarations

<!-- Declare or reference the types that constraints operate over.
     If a model exists, reference its type definitions. If not, declare
     them here to ground the constraints in typed entities.

     Example:
     ```
     TYPE SessionState = INACTIVE | AUTHENTICATING | ACTIVE | EXPIRED
     TYPE Session = { state: SessionState, token: Maybe<Token>, owner: Principal }
     ```
-->

### Invariants

<!-- Properties that MUST hold at all times, across all states.
     These are universally quantified — they cannot be violated by any
     valid state transition.

     Format:
     **[invariant-id]**: [Natural language description using BCP 14 keywords]
     `VERIFIED: [proof | machine | agent-check | unverified]`

     Formal notation (Tier 2+):
     ```alloy
     fact invariant_id { ... }
     ```
     or
     ```tla+
     Invariant == ...
     ```

     Example:
     **session-token-required**: An active session MUST have a non-null token.
     `VERIFIED: machine`
-->

- ...

### Transitions

<!-- Permitted state changes with pre-conditions and post-conditions.
     Pre-conditions define what MUST be true before a transition fires.
     Post-conditions define what MUST be true after.

     Format:
     **[transition-id]**: [Description]
     - **PRE**: [What MUST hold before]
     - **POST**: [What MUST hold after]
     `VERIFIED: [proof | machine | agent-check | unverified]`

     Example:
     **activate-session**: A session MAY transition to ACTIVE only from AUTHENTICATING.
     - **PRE**: session.state == AUTHENTICATING AND session.token != null
     - **POST**: session.state == ACTIVE
     `VERIFIED: machine`
-->

- ...

### Forbidden States

<!-- States that MUST NEVER be reachable. These are existentially negated —
     if the system can reach one of these states, the specification is violated.

     Format:
     **[forbidden-id]**: [Description of the forbidden condition]
     `VERIFIED: [proof | machine | agent-check | unverified]`

     Example:
     **no-tokenless-active**: A session MUST NOT be ACTIVE with a null token.
     `VERIFIED: machine`
-->

- ...

### Behavioral Properties

<!-- Optional. Temporal or behavioral properties that describe what the system
     MUST or MUST NOT do over time. These go beyond single-state invariants
     to describe sequences, liveness, and safety properties.

     Safety: "Something bad MUST NEVER happen"
     Liveness: "Something good MUST eventually happen"

     Format:
     **[property-id]**: [Description using BCP 14 keywords]
     - **Type**: [Safety | Liveness]
     `VERIFIED: [proof | machine | agent-check | unverified]`

     Example:
     **eventual-expiry**: An inactive session MUST eventually transition to EXPIRED.
     - **Type**: Liveness
     `VERIFIED: agent-check`
-->

- ...

## Formal Specification

<!-- Optional. Tier 2+ only. The complete formal specification in the
     selected notation (Alloy, TLA+, Lean, etc.). If Tier 1, omit this
     section entirely.

     This section contains the machine-checkable source of truth.
     The Constraints section above provides the human-readable summary;
     this section provides the formal definition.

     Include the full specification text, not just excerpts.
     The formal spec and the prose constraints MUST be consistent —
     any divergence is a specification defect. -->

## Verification

<!-- Document verification results. For each constraint, record:
     - What was checked
     - How it was checked (tool, method)
     - Result (pass, fail, partial)
     - Any counterexamples or edge cases discovered

     If formal tools were used, record the tool version, scope bounds
     (for Alloy), and any assumptions made during verification. -->

| Constraint | Method | Result | Detail |
| :--------- | :----- | :----- | :----- |
| ...        | ...    | ...    | ...    |

## Implications

<!-- What does the specification reveal for downstream work?

     Consider:
     - Implementation guidance: what /core MUST respect
     - Testing strategy: what property-based tests to write
     - Planning constraints: what downstream work MUST NOT violate
     - Model gaps: what the specification reveals about model inadequacies
     - Open questions: what the specification cannot answer -->
