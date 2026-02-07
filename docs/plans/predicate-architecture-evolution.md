# PLAN: Predicate Architecture Evolution

## Goal

Evolve Predicate's terminology and directory structure to improve agent clarity and reduce failure modes. Rename `predicates` → `axioms` (always-active rules) and `fragments` → `personas` (adoptable context). Add scan echo, structured confirmation, and workflow-persona binding.

## Constraints

- Must remain compatible with AGENTS.md standard
- Hard break acceptable (project unstable, single primary user)
- Changes must improve agent compliance, not just aesthetics
- README for humans; AGENTS.md/PREDICATE.md for agents

## Decisions

| Decision            | Choice                                            | Rationale                                                         |
| :------------------ | :------------------------------------------------ | :---------------------------------------------------------------- |
| Terminology         | predicates→axioms, fragments→personas             | Axioms connote non-negotiable; personas connote adoptable context |
| Directory structure | `.agent/axioms/` + `.agent/personas/` as siblings | Cleaner hierarchy; both are peer concepts                         |
| Available personas  | Implicit (everything in `personas/`)              | Reduces maintenance burden; only "Active" is explicit             |
| Workflow binding    | `required_personas:` in frontmatter               | Workflows can require specific personas                           |
| Backwards compat    | Hard break                                        | Project is unstable; consistency > compat                         |
| Project name        | Keep "Predicate"                                  | Axiom/persona are internal terms; Predicate is umbrella           |
| Scan verification   | Agent echoes found axioms/personas                | Makes scanning verifiable                                         |
| Missing persona     | HALT and ask human                                | Explicit failure better than silent skip                          |

## Scope

### In Scope

- Rename `predicates/` → `axioms/`
- Move `predicates/fragments/` → `personas/` (as sibling)
- Move `integral.md` to axioms (it's always-on)
- Rewrite `PREDICATE.md` with numbered protocol + structured confirmation
- Update `README.md`, `AGENTS.md`, and templates
- Add `required_personas:` to workflow frontmatter schema
- Update `/core` workflow to demonstrate persona binding

### Out of Scope

- Adding new axioms or personas
- Changing workflow mechanics beyond persona binding
- Backwards compatibility support

## Phases

1. ~~**Phase 1: Directory Restructure** — establish new directory layout~~ ✅
   - ~~Rename `predicates/` → `axioms/`~~
   - ~~Create `personas/` as sibling directory~~
   - ~~Move fragment files to `personas/`~~
   - ~~Move `integral.md` to `axioms/`~~

2. ~~**Phase 2: PREDICATE.md Rewrite** — establish new protocol format~~ ✅
   - ~~Numbered protocol with HALT semantics~~
   - ~~Structured confirmation format~~
   - ~~Terminology clarifications (axiom, persona definitions)~~

3. ~~**Phase 3: Documentation Updates** — align all docs with new terminology~~ ✅
   - ~~Update `README.md` (structure, terminology)~~
   - ~~Update `AGENTS.md` (self-reference)~~
   - ~~Update `templates/AGENTS.md` (new format)~~

4. ~~**Phase 4: Workflow Enhancement** — add persona binding to workflows~~ ✅
   - ~~Add `required_personas:` to workflow schema in `plan.md` spec~~
   - ~~Update `/core` with `required_personas: [integral]`~~
   - ~~Update sketch/plan instructions to reference persona binding~~

## Verification

- [x] All axiom files accessible in new location
- [x] All persona files accessible in new location
- [x] PREDICATE.md protocol parseable by agent
- [x] Workflows with `required_personas` load required personas
- [x] Structured confirmation output matches spec
- [x] README reflects new structure accurately

## References

- Sketch: `.sketches/predicate-communication-refinement.md`
- ADR: `docs/adr/001-axioms-personas-evolution.md`
