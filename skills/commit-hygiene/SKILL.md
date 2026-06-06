---
name: commit-hygiene
description: |
  Rules, conventions, and constraints for formatting git commit messages and committing at logical boundaries.
  Trigger when:
  - Drafting, revising, or validating git commit messages.
  - Pausing at commit boundaries under the CORE or CONTINUE workflows.
  - Evaluating whether a changeset should be split into multiple commits.
  - Prompt contains keywords: commit message, git commit, conventional commits, commit hygiene, commit guidelines, logical boundary, spaghetti diff, atomic commit, commit boundary.
---

# Commit Hygiene

Guidelines and constraints for writing clear, structured, and reviewer-centric git commit messages. Every commit is a unit of structured information designed to optimize human comprehension and git history utility.

## Purpose

The goal of commit hygiene is not formatting for its own sake. The goal is a **clean, human-reviewable git history**.

A well-maintained history lets a human reviewer reconstruct the reasoning behind a codebase by reading `git log`. Every commit should answer: *what changed, why it changed, and where the logical boundary of that change is.* When history achieves this, it becomes a durable decision record — not just a log of file mutations.

This requires two things working together:

1. **Good commit messages** — clear, structured, motivated (covered by the formatting and communication rules below).
2. **Commits at logical boundaries** — each commit captures one coherent unit of change with a reviewable diff (covered by the Atomicity and Boundary Discipline section below).

Neither is sufficient alone. A perfectly formatted message attached to a 40-file spaghetti diff is useless. A clean single-file diff with a message that says "update stuff" is nearly as bad. Both disciplines are required, always — not only when a formal workflow like C.O.R.E. is active.

## Hard Constraints

All commit messages MUST satisfy these structural invariants:
1. **Header Line Limit:** The summary line MUST NOT exceed **50 characters**.
2. **Body Line Limit:** No line in the body or footer may exceed **72 characters**.
3. **Blank Line Separation:** A single blank line MUST separate the header from the body.

---

## Conventional Commits Structure

Commits must conform to the Conventional Commits v1.0.0 specification:

```
<type>(<scope>)[!]: <description>

[optional body]

[optional footer(s)]
```

### Breaking Changes

A breaking change must be indicated by:
- An exclamation mark `!` suffixing the type or scope in the summary header (e.g., `feat!: remove deprecated api` or `fix(parser)!: adjust breaking parser logic`).
- A `BREAKING CHANGE: <description>` footer entry.

### Allowed Types

- `feat`: Introduction of a new capability or feature.
- `fix`: Resolution of a bug or regression.
- `docs`: Additions or modifications to documentation.
- `style`: Formatting, whitespace adjustments, or cosmetic corrections (no functional change).
- `refactor`: Structural codebase changes that neither modify behavior nor add features.
- `perf`: Optimizations that improve execution speed or resource utilization.
- `test`: Addition, restructuring, or correction of tests.
- `build`: Modifications to build configuration, dependencies, or packaging (e.g. `Cargo.toml`, `package.json`, `go.mod`).
- `ci`: Alterations to CI pipeline or automation configurations.
- `chore`: Auxiliary tasks, infrastructure tooling updates, or miscellaneous maintenance.
- `revert`: Reversion of a previous commit.

### Summary Header Formatting

- **Imperative Mood:** Use active, imperative verbs ("add", "fix", "refactor", "remove") rather than past-tense or present-participle ("added", "fixing", "refactored", "removes").
- **No Trailing Period:** The header line must not end with a period.
- **Lower Case:** The description after the colon should start with a lowercase letter (unless referencing a proper noun or acronym).

---

## Human-Centric Communication

Commits are written for human reviewers, not systems. Prioritize cognitive clarity:

### Focus on "Why" and "What"

- **The "Why":** Explain the motivation behind the change. What problem is this resolving? What context is required to understand this design decision?
- **The "What":** Describe what was changed at a conceptual level. Avoid summarizing the raw code diff (which the reviewer can already see); instead, describe the logical transition of the system.
- **Explain the Tradeoffs:** If a non-obvious design pattern or workaround was employed, document it honestly.

### Atomicity and Boundary Discipline

- Each commit must represent a single, cohesive logical change.
- **Proactive boundary identification:** Before beginning a task, identify the natural commit boundaries. If a task involves multiple logical steps (e.g., "add a type, then update callers, then add tests"), each step is a candidate boundary. Do not defer this judgment to the end — plan where you will commit before you start writing code.
- **Reviewable diffs:** Every diff attached to a commit must be reviewable by a human in one sitting without losing the thread. If a diff touches many files across unrelated concerns, it has crossed a boundary that should have been a separate commit.
- **Anti-pattern — spaghetti diffs:** Massive, entangled diffs that span multiple logical changes are the primary failure mode of git history. They make review impossible, bisect useless, and revert dangerous. Avoiding them is not optional.
- **Anti-pattern — "and" commits:** If a commit message requires the word "and" to describe its change (e.g., `feat: add user login and fix lint errors`), evaluate whether it should be split.
- **This applies universally.** Logical boundary discipline is a de facto standard for all codebase work — not a feature of any specific workflow. C.O.R.E. formalizes it with explicit commit gates, but the underlying obligation exists whether or not C.O.R.E. is active.

---

## Commit Checklist

Before presenting a commit, run this audit:

### Message Quality
- [ ] Is the header length ≤ 50 characters?
- [ ] Are all body and footer lines ≤ 72 characters?
- [ ] Is there a blank line between the header and the body?
- [ ] Is the header in the imperative mood?
- [ ] Does it use a valid Conventional Commit type?
- [ ] Does the body explain the *why* and *what*, rather than just reproducing the diff?
- [ ] Are breaking changes explicitly denoted using `!` in the header and/or a `BREAKING CHANGE: <description>` footer?

### Boundary Discipline
- [ ] Does this commit represent a single, cohesive logical change?
- [ ] Is the diff reviewable by a human without losing the thread?
- [ ] Does the commit avoid mixing unrelated concerns?
- [ ] If the message needs "and" to describe the change, should this be split?
