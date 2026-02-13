# MODEL: [Domain Name]

<!--
  MODEL documents are formal domain model artifacts produced by the /model workflow.
  They formalize a domain's structure using the Structural Domain Modeling Atlas (SDMA).

  See: workflows/model.md for the full protocol specification.
  See: personas/sdma.md for the applied modeling toolkit.
  See: axioms/formal-foundations.md for the mathematical foundations.
-->

## Domain Classification

<!-- What problem domain is being modeled? Why does it warrant formal modeling?
     What are the domain's essential characteristics (state, resources, protocols,
     constraints, metrics)? If this model was produced in Apply mode, identify
     the source document being scrutinized. -->

**Problem Statement:**

**Source Document:** <!-- Apply mode only. Remove this line in Create mode. -->

**Domain Characteristics:**

- ...

## Formalism Selection

<!-- Which SDMA formalism was selected and why? Reference the Decision Matrix
     (SDMA §6). Document alternatives considered and why they were rejected.
     If multiple formalisms are layered, explain the layering strategy. -->

| Aspect                  | Detail |
| :---------------------- | :----- |
| **Primary Formalism**   | ...    |
| **Supporting Tools**    | ...    |
| **Decision Matrix Row** | ...    |
| **Rationale**           | ...    |

**Alternatives Considered:**

- ...

## Model

<!-- The formal model itself. This section is open-ended and domain-specific.
     Follow the SDMA persona's guidelines for the chosen formalism:

     - Ologs: singular indefinite noun phrases, functional morphisms,
       commutative diagram facts (SDMA §2)
     - Coalgebras: state space, interface functor, observable behavior,
       bisimulation relations (SDMA §3)
     - Session Types: channel types, duality, protocol grammar (SDMA §4)
     - LinRel: signal flow diagrams, Frobenius structure, conservation
       laws (SDMA §8)
     - Hyperdoctrines: base category, fibres, quantifiers as adjoints,
       reindexing functors (SDMA §9)

     Use diagrams, tables, and formal notation as appropriate. The model
     should be precise enough to verify and compositional enough to extend.
-->

## Validation

<!-- Document internal consistency checks and external adequacy assessment.

     Internal consistency:
     - Diagram commutativity (ologs)
     - Bisimulation closure (coalgebras)
     - Session type duality (session types)
     - Conservation law satisfaction (LinRel)
     - Quantifier adjunction verification (hyperdoctrines)

     External adequacy:
     - Does the model capture the domain faithfully?
     - Are there domain properties the model cannot express?
     - Is the model unnecessarily complex (minimality)?
-->

| Check | Result            | Detail |
| :---- | :---------------- | :----- |
| ...   | PASS/FAIL/PARTIAL | ...    |

## Implications

<!-- What does the model reveal for downstream work? This is where formal
     modeling pays dividends — the model should surface non-obvious properties,
     potential failure modes, or structural insights that informal reasoning misses.

     Consider:
     - Implementation guidance (what the code structure should look like)
     - Testing strategy (what properties to test, what bisimulations to check)
     - Architecture decisions (what the model says about component boundaries)
     - Design flaws revealed (if Apply mode — what the source document gets wrong)
     - Open questions (what the model cannot answer)
-->
