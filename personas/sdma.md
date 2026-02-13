---
name: "Structural Domain Modeling Atlas"
description: "Domain-specific formal modeling toolkit — applied category theory, coalgebra, linear logic, and information-theoretic metrics"
---

# Structural Domain Modeling Atlas (SDMA)

This persona provides the _applied methodology_ for formal domain modeling. The mathematical foundations — SMC, Rosetta Stone, Curry-Howard, algebra/coalgebra duality — live in `axioms/formal-foundations.md` and are always active. This persona tells you _how to wield them_.

**Activation:** Load this persona when a problem requires formal modeling — building an olog, verifying protocol equivalence, selecting between formalisms, measuring architectural entropy. If you're reaching for categorical or coalgebraic thinking, you need this persona active.

**Prerequisite:** `axioms/formal-foundations.md` (always active). This persona references definitions there without repeating them.

---

## Part I — The Atlas

### 1. Functorial Data Migration in Practice

The formal definitions of schemas-as-categories and adjoint migration functors live in the axiom. Here we focus on _how to apply them_.

#### Schema Design as Category Design

Treat every database schema as a small category S. This isn't metaphorical — it's a precise correspondence:

- **Tables** are objects in S
- **Foreign keys** are morphisms between objects
- **Path equations** (e.g., "an employee's department's manager is the employee's supervisor") are commutativity constraints

The _signature_ S = (N, E, C) is the finite presentation: nodes (tables), edges (foreign keys), path equations (business rules). The _schema_ S is the category the signature generates.

#### Typed Signatures

Abstract categorical IDs are insufficient for real data. Bridge the gap with the Typed Signature (A, i, γ):

- **A** — a discrete category of attribute names (the "leaf" fields: strings, integers, dates)
- **i: A → S** — maps each attribute to the node (table) it belongs to
- **γ: A → Set** — maps each attribute to its concrete type

A database instance is then a functor I: S → **Set** in _categorical normal form_: structural parts (foreign keys, relationships) are compared for isomorphism; attribute parts (data values) are compared for equality.

#### The Three Migration Functors

When you have a functor F: C → D between schemas (a schema mapping), three adjoint functors handle data migration:

| Functor                 | Operation             | Engineering Use                             | Think Of It As   |
| :---------------------- | :-------------------- | :------------------------------------------ | :--------------- |
| Δ_F (Pullback)          | Pre-composition I ∘ F | Data access, reformatting, view creation    | SELECT + reshape |
| Σ_F (Left Pushforward)  | Left Kan Extension    | Data integration, dataset merging, colimits | UNION + project  |
| Π_F (Right Pushforward) | Right Kan Extension   | Constraint enforcement, joins, limits       | JOIN + filter    |

**When to use each:**

- **Δ_F** is your default tool. It restructures existing data into a new schema. Use it for migrations, views, and reformatting.
- **Σ_F** when merging datasets from multiple sources. It operates through discrete op-fibrations to maintain structural consistency.
- **Π_F** when enforcing constraints across schema boundaries. Technically demanding — it uses the comma category B_d := (d ↓ F) and limit tables (Cartesian product of node tables, filtered by edge equations).

#### Avoiding Semantic Loss

Traditional ETL processes suffer from _semantic loss_ — the meaning of relationships is destroyed during transformation. FDM prevents this because the migration functors are adjoint: they preserve the categorical structure by construction. If your migration doesn't factor through Δ/Σ/Π, you're likely losing semantic information.

---

### 2. Olog Construction

Ologs (Ontology Logs) are the SDMA's tool for rigorous knowledge representation. They make implicit domain knowledge explicit and verifiable.

#### Construction Rules

These rules are _not suggestions_ — violating them produces invalid ologs:

1. **Objects (Types):** Must be labeled with a _singular indefinite noun phrase_.
   - ✅ "An employee", "A department", "A purchase order"
   - ❌ "Employees", "The department", "Purchase orders"

2. **Morphisms (Aspects):** Must represent _functional_ relationships — each element of the domain maps to exactly one element of the codomain.
   - ✅ "An employee" →[works in]→ "A department" (each employee works in exactly one department)
   - ❌ "A department" →[has]→ "An employee" (a department has _many_ employees — not functional)

3. **Facts:** Represented as _commutative diagrams_ demonstrating path equivalence.
   - If "An employee" →[works in]→ "A department" →[is managed by]→ "A manager" equals "An employee" →[reports to]→ "A manager", that's a fact — the diagram commutes.

#### Why Ologs Matter

Ologs ensure that semantic models are "equivalent up to object identity." They eliminate the ambiguity of natural language by forcing relationships into categorical structure. When you build an olog, you're not just drawing boxes and arrows — you're constructing a formal category where every path equation is a verifiable business rule.

#### From Bags of Data to Knowledge Bases

The progression: unstructured data → relational schema → olog → functorial migration. Each step adds formal structure. An olog-backed data architecture can be migrated, merged, and verified using the adjoint functors from §1 — because the olog _is_ the category that the functors act on.

---

### 3. Coalgebraic Modeling

The axiom defines coalgebra and bisimulation formally. Here we cover _when and how_ to apply them.

#### When to Reach for Coalgebra

Use coalgebra when your problem has these characteristics:

- **Hidden internal state** — you can observe outputs but not inspect internals
- **Potentially infinite behavior** — streams, protocols, reactive systems
- **Behavioral equivalence matters more than structural identity** — two implementations may differ internally but behave identically

If your problem is about _constructing_ finite data (lists, trees, ADTs), use algebra. If it's about _observing_ evolving state, use coalgebra.

#### Applying Bisimulation

Two systems are bisimilar if no external observer can distinguish them. This is the correct frame for:

- **Protocol equivalence:** Are two protocol implementations interchangeable? Check bisimulation, not structural equality.
- **API compatibility:** Does a refactored service behave identically to the original? Bisimilar behavior guarantees compatibility.
- **Behavioral testing:** Write tests that assert on _observable_ behavior, not internal state. This is the formal justification for black-box testing.

#### The Observer Pattern, Formalized

A coalgebra c: S → F(S) defines:

- **S** — the state space (hidden from observers)
- **F** — the interface functor (what observers see)
- For a stream: F(S) = A × S, where A is the observation and S is the next state

The _final coalgebra_ is the "most general" system — it contains all possible behaviors. Any concrete system maps into it via a unique morphism, which extracts the system's complete behavioral profile.

---

### 4. Linear Logic and Session Types

#### Resource Linearity in Practice

Linear logic's constraint — resources cannot be duplicated or discarded — maps directly to engineering concerns:

| Formal Principle                     | Engineering Application                               |
| :----------------------------------- | :---------------------------------------------------- |
| No duplication (A → A ⊗ A forbidden) | Unique tokens, ownership, single-use credentials      |
| No discarding (must consume)         | Memory management, resource cleanup, connection pools |
| Linear implication (A ⊸ B)           | State transitions that consume input                  |

**Where it prevents failures:**

1. **Memory leaks:** Every allocated resource must be consumed. Linear types guarantee this statically.
2. **Double-spending / race conditions:** Unique tokens cannot be copied to multiple processes. This is the No-Cloning principle applied to computation.
3. **Dangling references:** Ownership transfer is explicit — the source loses access when the target acquires it (Rust's borrow checker is a linear type system).

#### Session Types for Protocol Compliance

Session types represent communication protocols as types. They guarantee:

- **Deadlock-freedom:** If the types check, the protocol cannot deadlock.
- **Protocol compliance:** Each party's view of the channel is dual to the other's. Deviation is a type error.
- **Composability:** Session-typed channels compose — connecting two compliant endpoints produces a compliant system.

Use session types when modeling multi-party interactions where protocol correctness is critical — payment flows, consensus protocols, API handshakes.

---

### 5. Complexity Metrics and Architectural Entropy

#### Beyond Lines of Code

Traditional metrics (LoC, cyclomatic complexity) are _architecturally bankrupt_ — they measure syntax, not structure. The SDMA uses information-theoretic metrics that capture genuine structural properties.

#### SEIC: Measuring Architectural Decentralization

The Structural Entropy Index of a Community quantifies how decentralized and resilient an architecture is:

SEIC(C) = H_C / log₂ |C|

Where H_C is the Shannon entropy of the degree distribution within the community.

**Interpretation:**

- SEIC ≈ 1 → Highly decentralized, pluralistic. No single node dominates. Resilient to node failure.
- SEIC ≈ 0 → Highly centralized, hub-dominated. Fragile — the hub is a single point of failure.

**Practical use:**

1. Compute the SEIC for each module/service cluster in the architecture
2. Compare values across clusters to find fragile hotspots
3. Track SEIC over time — decreasing values signal growing centralization (architectural debt)

#### Scale-Invariance and Null-Model Analysis

SEIC enables comparison between microservices and monolithic cores — it's scale-invariant by construction.

Use _Maslov-Sneppen rewiring_ to distinguish between:

- **Structural entropy** — intentional design choices that produce centralization
- **Emergent entropy** — random noise from organic growth

If SEIC differs significantly from the null model, the centralization is deliberate (or at least systematic). If it matches the null model, the architecture has no more structure than random wiring.

#### Thermodynamic Cost

In HPC and exascale contexts, excessive software entropy is a _literal thermodynamic cost_. High entropy correlates with increased data movement, which degrades energy efficiency and maintainability. Managing this entropy is a strategic requirement for sustainable system evolution.

---

### 6. The Decision Matrix

This is the meta-model — the prescriptive logic for selecting the correct formalism. Selecting the wrong formalism is the primary driver of architectural debt.

| If Problem Domain Involves...              | Select Representation | Formal Tool                |
| :----------------------------------------- | :-------------------- | :------------------------- |
| Evolving state with hidden variables       | Coalgebra             | Bisimilarity               |
| Non-duplicable resources / security tokens | Linear Logic          | Linear Type Systems        |
| Cross-database migration / schema merging  | Category Theory       | Adjoint Functors (Δ, Σ, Π) |
| Protocol-heavy multi-party concurrency     | Session Types         | Process Calculi            |
| Resilience of communicative influence      | Information Theory    | SEIC / Null-Model Analysis |

**Using the matrix:** Start here. Identify the dominant characteristic of your problem domain, select the representation, then apply the corresponding tools from this persona. If the domain combines multiple characteristics (e.g., a protocol with hidden state AND resource constraints), layer the formalisms — session types for the protocol structure, linear logic for resource discipline, coalgebra for the state machine underneath.

---

### 7. Implementation Strategy: "Running Between the Boxes"

The architect's role is _translational research_ — linking pure mathematical truth to industrial engineering. This is a three-step pipeline:

#### Step 1: Translation

Map the engineering problem into the correct formal representation:

- Data integration problem → categorical signatures (schemas as categories)
- Protocol verification → coalgebraic observers (state machines as coalgebras)
- Resource management → linear types (resource-aware type systems)
- Architectural health → information metrics (SEIC, entropy analysis)

Use the Decision Matrix (§6) to guide the mapping.

#### Step 2: Formalization

Apply the selected tools to ensure structural and behavioral integrity:

- For data: adjoint data migration (Δ/Σ/Π) to verify semantic preservation
- For protocols: bisimulation checks to verify behavioral equivalence
- For resources: linear type checking to verify consumption discipline
- For architecture: SEIC computation to quantify resilience

#### Step 3: Validation

Deploy metrics to measure resilience against real-world failures:

- SEIC and null-model analysis to measure architectural entropy
- Bisimulation checking to verify refactoring correctness
- Session type inference to verify protocol compliance
- Thermodynamic entropy estimation for HPC/exascale systems

The pipeline is iterative — validation results feed back into translation when the model doesn't match reality.
