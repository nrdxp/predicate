# PLAN: SDMA Integration into Predicate

## Goal

Incorporate the Structural Domain Modeling Atlas (SDMA) — a corpus distilled from 100+ academic sources covering category theory, Curry-Howard, Baez-Stay Rosetta Stone, information theory, and formal domain modeling — into Predicate's three-tier architecture. The result: an axiom for universal mathematical foundations, a persona for the domain-specific modeling toolkit, and a `/model` workflow for producing formal model documents.

## Constraints

- Full substantive depth must be preserved — no dilution of the source material's resolution
- Must respect Predicate's axiom/persona/workflow architecture with clear boundaries
- Axiom content must be universally applicable, not domain-specific
- The `/model` workflow must produce durable artifacts committed to the main repository
- Content must be actionable for agents, not merely academic reference

## Decisions

| Decision                       | Choice                                                                                          | Rationale                                                                                                                                    |
| :----------------------------- | :---------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------- |
| Axiom scope                    | Mathematical foundations (Rosetta Stone, SMC, Curry-Howard, algebra/coalgebra)                  | These shape reasoning across _all_ CS domains — they're thinking tools, not domain-specific                                                  |
| Persona scope                  | Applied domain toolkit (FDM, ologs, linear logic, session types, SEIC, all four gap extensions) | These are specialized tools activated only when formal modeling is needed                                                                    |
| Model output location          | `docs/models/` in main repo                                                                     | Formal models are durable public artifacts, like plans and ADRs — not exploratory notes                                                      |
| Single persona file vs. suite  | Single `personas/sdma.md`                                                                       | Cross-domain unity is the Rosetta Stone's core value; fragmenting by domain hides connections                                                |
| Axiom naming                   | `formal-foundations.md`                                                                         | Descriptive of contents; avoids overly narrow names like "category-theory"                                                                   |
| Pipeline position for `/model` | Between `/sketch` and `/plan` (also standalone)                                                 | Formal modeling informs planning and implementation but is not planning itself                                                               |
| Model template                 | `templates/MODEL.md` with shared structural skeleton                                            | Models vary wildly in content but share structural concerns (domain, selection, model, validation, implications) — same pattern as `PLAN.md` |
| Workflow modes                 | Dual-mode: create (new model document) and apply (scrutinize/refine existing document)          | Formal modeling discipline applies both when creating standalone models and when analyzing existing specs, whitepapers, or protocols         |

## Risks & Assumptions

| Risk / Assumption                                                                       | Severity | Status       | Mitigation / Evidence                                                                                                                                                                             |
| :-------------------------------------------------------------------------------------- | :------- | :----------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Persona size (~30-40KB) is 2x larger than any existing persona                          | MEDIUM   | Acknowledged | Clear internal structure with section headings enables targeted navigation. `python.md` is already 19KB.                                                                                          |
| Axiom/persona boundary overlap — foundations vs. application share conceptual territory | MEDIUM   | Mitigated    | Clear boundary: axiom = "what these mathematical structures _are_"; persona = "how to _apply_ them to specific problems"                                                                          |
| Agent context window strain from large persona                                          | LOW      | Acknowledged | The persona is opt-in — only loaded when formal modeling is relevant. Modern context windows handle 30-40KB well.                                                                                 |
| Mathematical notation in markdown may render inconsistently                             | LOW      | Accepted     | LaTeX-style notation is standard in the source documents. Markdown handles it adequately for agent consumption.                                                                                   |
| No existing predicate content tests — verification is structural review only            | LOW      | Accepted     | This is a documentation-only repository. Verification is through manual review and structural checks.                                                                                             |
| Assumption: agents benefit from always-active mathematical vocabulary                   | —        | Validated    | The Rosetta Stone framing improves categorical thinking about types, composition, and proofs even in routine engineering. This is the same rationale as `integral.md`'s Big 5 personality matrix. |
| Assumption: `/model` workflow pattern fits existing pipeline structure                  | —        | Validated    | `/charter → /sketch → /model → /plan → /core` is a natural extension. `/model` follows the same `required_personas:` pattern as existing workflows.                                               |

## Open Questions

- None. All questions resolved during SKETCH phase (depth: human confirmed full preservation; workflow: human confirmed `/model`; storage: human confirmed `docs/models/`).

## Scope

### In Scope

- Create `axioms/formal-foundations.md` from `sdma-foundations.txt` with agent-directed framing
- Create `personas/sdma.md` from `sdma.txt` + `sdma-extents.txt` with full depth preserved
- Create `workflows/model.md` with 6-step procedure and dual-mode operation (create/apply)
- Create `templates/MODEL.md` with shared structural skeleton for model documents
- Update `planning.md` persona to reference `/model` in the pipeline
- Update repository structure table in `AGENTS.md` and `README.md` to reference `docs/models/`
- Remove source `.txt` files from repo root after content is incorporated

### Out of Scope

- Modifying `engineering.md` or `integral.md` (the axiom supplements, not modifies)
- Implementing any AlgebraicJulia/Catlab.jl code
- Adding automated tests (documentation-only repository)
- Creating an ADR (this is content addition, not an architectural decision that constrains future work)

## Phases

1. **Phase 1: Axiom — `axioms/formal-foundations.md`** — Create the always-active mathematical foundations axiom

   Source: primarily `sdma-foundations.txt`
   - [x] Write axiom frontmatter (name, description)
   - [x] Section: Categorical Foundations (SMC, closed categories, compact closed)
     - Pentagon and hexagon identities
     - Currying isomorphism
     - Zig-zag (yanking) identities
   - [x] Section: The Rosetta Stone Isomorphisms
     - Physics ↔ Topology ↔ Logic ↔ Computation correspondence
     - Full summary reference table
   - [x] Section: Algebra vs. Coalgebra
     - Induction vs. co-induction
     - Constructors vs. observers
     - Structural identity vs. bisimilarity
   - [x] Section: Curry-Howard and Compositional Reasoning
     - Types are propositions, programs are proofs
     - Practical implications for agent reasoning
   - [x] Section: Integration with Existing Axioms
     - Relationship to `integral.md` (holonic thinking, Deep Think Protocol)
     - Relationship to `engineering.md` (strong typing, SOLID)
     - Precedence: `engineering.md` > `formal-foundations.md` > `integral.md`

2. **Phase 2: Persona — `personas/sdma.md`** — Create the comprehensive domain modeling persona

   Source: `sdma.txt` (Atlas) + `sdma-extents.txt` (Extensions)
   - [ ] Write persona frontmatter (name, description)
   - [ ] Part I — The Atlas (from `sdma.txt`):
     - [ ] Functorial Data Migration (schemas as categories, Δ/Σ/Π adjoints, typed signatures, categorical normal form)
     - [ ] Ologs (construction rules, noun phrase labels, functional morphisms, commutative diagram facts)
     - [ ] Coalgebraic State Machines (bisimulation, observable behavioral equivalence)
     - [ ] Linear Logic & Session Types (resource linearity, no-cloning, deadlock-freedom)
     - [ ] Algorithmic Information Theory (SEIC, Kolmogorov complexity, null-model analysis, thermodynamic entropy)
     - [ ] Decision Matrix (prescriptive formalism selection logic table)
     - [ ] "Running Between the Boxes" implementation strategy (Translation → Formalization → Validation)
   - [ ] Part II — Advanced Extensions (from `sdma-extents.txt`):
     - [ ] Control Gap (signal flow diagrams, linear relations, Frobenius algebras, LinRel vs. discrete)
     - [ ] Constraint Gap (fibrations, hyperdoctrines, triposes, quantifiers as adjoints, olog→hyperdoctrine→tripos hierarchy)
     - [ ] Uncertainty Gap (Markov kernels, effective topos, Markov's principle, PERs, many-valued logic)
     - [ ] Verification Gap (Stone duality, coalgebraic modal logic, system dynamics ↔ system specification)

3. **Phase 3: Workflow — `workflows/model.md`** — Create the /model workflow
   - [ ] Write workflow frontmatter (name, description, trigger, required_personas)
   - [ ] Section: Scope and pipeline position
   - [ ] Section: Dual-mode operation
     - Create mode: no target document → produce new model from `templates/MODEL.md` to `docs/models/`
     - Apply mode: target document specified → scrutinize/refine existing document (protocol spec, whitepaper, etc.) through SDMA lens
   - [ ] Section: Grammar (YAML state tracking structure)
   - [ ] Section: 6-step procedure (IDENTIFY → SELECT → CONSTRUCT → VALIDATE → RECORD → CONNECT)
     - Document how each step adapts between create and apply modes
   - [ ] Section: State transitions and HALT points
   - [ ] Section: Model document output format and `docs/models/` directory
   - [ ] Section: Template discipline (MODEL.md canonical format, create mode only)
   - [ ] Section: Integration with sketch lifecycle journal
   - [ ] Create `templates/MODEL.md` with shared structural skeleton:
     - Domain Classification (problem statement, why formal modeling is warranted)
     - Formalism Selection (decision matrix output, rationale, alternatives considered)
     - Model (open-ended, domain-specific: olog, coalgebra, session type, etc. — with guidance notes per domain)
     - Validation (internal consistency checks, constraints satisfied, diagram commutativity)
     - Implications (what the model reveals for downstream design, implementation, testing)

4. **Phase 4: Integration updates** — Update existing files to reference the new content
   - [ ] Update `planning.md` persona pipeline references to include `/model`
   - [ ] Update `AGENTS.md` repository structure table
   - [ ] Update `README.md` to mention models directory and SDMA content
   - [ ] Remove `sdma.txt`, `sdma-foundations.txt`, `sdma-extents.txt` from repo root

## Verification

- [ ] `axioms/formal-foundations.md` exists, has valid frontmatter, and covers all sections from `sdma-foundations.txt` without dilution
- [ ] `personas/sdma.md` exists, has valid frontmatter, and covers all content from `sdma.txt` and `sdma-extents.txt` without dilution
- [ ] `workflows/model.md` exists, has valid frontmatter with `required_personas: [sdma]`, and follows existing workflow structure conventions
- [ ] `templates/MODEL.md` exists with Domain Classification, Formalism Selection, Model, Validation, and Implications sections
- [ ] `planning.md` references `/model` in the pipeline
- [ ] `AGENTS.md` and `README.md` structure tables updated
- [ ] Source `.txt` files removed from repo root
- [ ] No content dilution: spot-check ≥3 specific mathematical definitions from source docs to confirm they appear with full detail in the axiom/persona

## Technical Debt

| Item | Severity | Why Introduced | Follow-Up | Resolved |
| :--- | :------- | :------------- | :-------- | :------: |

## Retrospective

<!-- To be filled after execution -->

### Process

### Outcomes

### Pipeline Improvements

## References

- Sketch: `.sketches/2026-02-13-sdma-integration.md`
- Source Documents: `sdma.txt`, `sdma-foundations.txt`, `sdma-extents.txt` (repo root, to be removed after integration)
